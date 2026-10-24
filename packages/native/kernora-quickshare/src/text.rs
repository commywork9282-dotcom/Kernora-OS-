// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::sync::OnceLock;

fn russian() -> bool {
    static RUSSIAN: OnceLock<bool> = OnceLock::new();
    *RUSSIAN.get_or_init(|| {
        for key in ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"] {
            if let Ok(value) = std::env::var(key) {
                let value = value.trim();
                if !value.is_empty() {
                    return value.starts_with("ru");
                }
            }
        }
        false
    })
}

pub fn pick<'a>(english: &'a str, russian_text: &'a str) -> &'a str {
    if russian() { russian_text } else { english }
}

pub fn unknown_device() -> String {
    pick("Unknown device", "Неизвестное устройство").to_string()
}

pub fn wants_to_share(device: &str) -> String {
    pick("{} wants to share", "{} хочет поделиться").replace("{}", device)
}

pub fn file_list(files: &[String]) -> String {
    let shown: Vec<&str> = files.iter().take(3).map(String::as_str).collect();
    let mut text = shown.join(", ");
    if files.len() > shown.len() {
        text.push_str(
            &pick(" and {} more", " и ещё {}").replace("{}", &(files.len() - shown.len()).to_string()),
        );
    }
    text
}

pub fn pin(pin: &str) -> String {
    pick("PIN {}", "PIN-код {}").replace("{}", pin)
}

pub fn accept() -> &'static str {
    pick("Accept", "Принять")
}

pub fn decline() -> &'static str {
    pick("Decline", "Отклонить")
}

pub fn receiving_from(device: &str) -> String {
    pick("Receiving from {}", "Получение от {}").replace("{}", device)
}

pub fn sending_to(device: &str) -> String {
    pick("Sending to {}", "Отправка на {}").replace("{}", device)
}

pub fn waiting_for(device: &str) -> String {
    pick("Waiting for {} to accept", "Ждём, пока {} примет").replace("{}", device)
}

pub fn received_from(device: &str) -> String {
    pick("Received from {}", "Получено от {}").replace("{}", device)
}

pub fn text_from(device: &str) -> String {
    pick("Text from {}", "Текст от {}").replace("{}", device)
}

pub fn link_from(device: &str) -> String {
    pick("Link from {}", "Ссылка от {}").replace("{}", device)
}

pub fn wifi_from(device: &str) -> String {
    pick("Wi-Fi network from {}", "Сеть Wi-Fi от {}").replace("{}", device)
}

pub fn open() -> &'static str {
    pick("Open", "Открыть")
}

pub fn open_folder() -> &'static str {
    pick("Show in folder", "Показать в папке")
}

pub fn copy() -> &'static str {
    pick("Copy", "Копировать")
}

pub fn connect() -> &'static str {
    pick("Connect", "Подключиться")
}

pub fn declined_by(device: &str) -> String {
    pick("{} declined", "{}: передача отклонена").replace("{}", device)
}

pub fn cancelled() -> &'static str {
    pick("The transfer was cancelled", "Передача отменена")
}

pub fn connection_lost() -> &'static str {
    pick("The connection was lost", "Соединение потеряно")
}

pub fn nearby_title() -> &'static str {
    pick("Someone nearby is sharing", "Кто-то рядом делится файлами")
}

pub fn nearby_body(name: &str) -> String {
    pick(
        "Make {} visible to everyone for 10 minutes to receive it",
        "Сделайте {} видимым для всех на 10 минут, чтобы принять",
    )
    .replace("{}", name)
}

pub fn make_visible() -> &'static str {
    pick("Make visible", "Сделать видимым")
}

pub fn app_name() -> &'static str {
    "Quick Share"
}
