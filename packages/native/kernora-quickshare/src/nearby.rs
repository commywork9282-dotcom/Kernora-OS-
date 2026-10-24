// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::time::{Duration, Instant};

pub const LOST: Duration = Duration::from_secs(30);
pub const SNOOZE: Duration = Duration::from_secs(900);

#[derive(Default)]
pub struct Nearby {
    seen: Option<Instant>,
    snoozed: Option<Instant>,
}

impl Nearby {
    pub fn seen(&mut self, now: Instant) -> bool {
        let fresh = self.seen.is_none_or(|seen| now.duration_since(seen) >= LOST);
        self.seen = Some(now);
        fresh
    }

    pub fn lost(&mut self, now: Instant) -> bool {
        let lost = self.seen.is_some_and(|seen| now.duration_since(seen) >= LOST);
        if lost {
            self.seen = None;
        }
        lost
    }

    pub fn snooze(&mut self, now: Instant) {
        self.snoozed = Some(now + SNOOZE);
    }

    pub fn snoozed(&self, now: Instant) -> bool {
        self.snoozed.is_some_and(|until| now < until)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(start: Instant, seconds: u64) -> Instant {
        start + Duration::from_secs(seconds)
    }

    #[test]
    fn one_prompt_while_a_phone_keeps_sharing() {
        let start = Instant::now();
        let mut nearby = Nearby::default();
        assert!(nearby.seen(start));
        for second in (2..300).step_by(10) {
            assert!(!nearby.seen(at(start, second)));
            assert!(!nearby.lost(at(start, second)));
        }
    }

    #[test]
    fn the_prompt_goes_when_the_phone_stops() {
        let start = Instant::now();
        let mut nearby = Nearby::default();
        nearby.seen(start);
        assert!(!nearby.lost(at(start, 29)));
        assert!(nearby.lost(at(start, 30)));
        assert!(!nearby.lost(at(start, 60)));
        assert!(nearby.seen(at(start, 61)));
    }

    #[test]
    fn a_new_share_after_a_pause_asks_again() {
        let start = Instant::now();
        let mut nearby = Nearby::default();
        nearby.seen(start);
        assert!(nearby.seen(at(start, 45)));
    }

    #[test]
    fn dismiss_keeps_it_quiet_for_fifteen_minutes() {
        let start = Instant::now();
        let mut nearby = Nearby::default();
        assert!(!nearby.snoozed(start));
        nearby.snooze(start);
        assert!(nearby.snoozed(at(start, 1)));
        assert!(nearby.snoozed(at(start, 899)));
        assert!(!nearby.snoozed(at(start, 900)));
    }
}
