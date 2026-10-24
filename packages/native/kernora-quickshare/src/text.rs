// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::path::Path;
use std::sync::OnceLock;

use crate::state::Transfer;

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

fn pick<'a>(english: &'a str, russian_text: &'a str) -> &'a str {
    if russian() { russian_text } else { english }
}

fn fill(template: &str, values: &[&str]) -> String {
    let mut out = template.to_string();
    for value in values {
        out = out.replacen("{}", value, 1);
    }
    out
}

fn russian_plural(count: usize, one: &str, few: &str, many: &str) -> String {
    let form = if count % 10 == 1 && count % 100 != 11 {
        one
    } else if (2..=4).contains(&(count % 10)) && !(12..=14).contains(&(count % 100)) {
        few
    } else {
        many
    };
    format!("{count} {form}")
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Image,
    Video,
    App,
    File,
    Link,
    Text,
}

const IMAGES: &[&str] = &["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff", "avif", "svg"];
const VIDEOS: &[&str] = &["mp4", "mkv", "mov", "webm", "avi", "3gp", "m4v", "mpg", "mpeg", "wmv"];

pub fn file_kind(name: &str) -> Kind {
    let extension = Path::new(name)
        .extension()
        .map(|e| e.to_string_lossy().to_ascii_lowercase())
        .unwrap_or_default();
    if IMAGES.contains(&extension.as_str()) {
        Kind::Image
    } else if VIDEOS.contains(&extension.as_str()) {
        Kind::Video
    } else if extension == "apk" {
        Kind::App
    } else {
        Kind::File
    }
}

pub fn image_mime(name: &str) -> Option<&'static str> {
    let extension = Path::new(name)
        .extension()
        .map(|e| e.to_string_lossy().to_ascii_lowercase())
        .unwrap_or_default();
    Some(match extension.as_str() {
        "jpg" | "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "bmp" => "image/bmp",
        "avif" => "image/avif",
        "heic" | "heif" => "image/heic",
        _ => return None,
    })
}

pub struct Items {
    pub kind: Kind,
    pub count: usize,
}

impl Items {
    pub fn of(transfer: &Transfer) -> Self {
        match transfer.kind {
            "url" => Items { kind: Kind::Link, count: 1 },
            "text" => Items { kind: Kind::Text, count: 1 },
            _ => {
                let count = transfer.files.len().max(1);
                let mut kinds = transfer.files.iter().map(|name| file_kind(name));
                let first = kinds.next().unwrap_or(Kind::File);
                let kind = if kinds.all(|kind| kind == first) { first } else { Kind::File };
                Items { kind, count }
            }
        }
    }

    pub fn lower(&self) -> String {
        let n = self.count;
        if russian() {
            return match self.kind {
                Kind::Image if n == 1 => "изображение".into(),
                Kind::Image => russian_plural(n, "изображение", "изображения", "изображений"),
                Kind::Video if n == 1 => "видео".into(),
                Kind::Video => format!("{n} видео"),
                Kind::App if n == 1 => "приложение".into(),
                Kind::App => russian_plural(n, "приложение", "приложения", "приложений"),
                Kind::File if n == 1 => "файл".into(),
                Kind::File => russian_plural(n, "файл", "файла", "файлов"),
                Kind::Link => "ссылку".into(),
                Kind::Text => "текст".into(),
            };
        }
        match self.kind {
            Kind::Image if n == 1 => "an image".into(),
            Kind::Image => format!("{n} images"),
            Kind::Video if n == 1 => "a video".into(),
            Kind::Video => format!("{n} videos"),
            Kind::App if n == 1 => "an app".into(),
            Kind::App => format!("{n} apps"),
            Kind::File if n == 1 => "a file".into(),
            Kind::File => format!("{n} files"),
            Kind::Link => "a link".into(),
            Kind::Text => "text".into(),
        }
    }

    pub fn noun(&self) -> String {
        let n = self.count;
        if russian() {
            return match self.kind {
                Kind::Image if n == 1 => "изображение".into(),
                Kind::Video if n == 1 => "видео".into(),
                Kind::App if n == 1 => "приложение".into(),
                Kind::File if n == 1 => "файл".into(),
                Kind::Link => "ссылка".into(),
                Kind::Text => "текст".into(),
                _ => self.lower(),
            };
        }
        match self.kind {
            Kind::Image if n == 1 => "Image".into(),
            Kind::Video if n == 1 => "Video".into(),
            Kind::App if n == 1 => "App".into(),
            Kind::File if n == 1 => "File".into(),
            Kind::Link => "Link".into(),
            Kind::Text => "Text".into(),
            _ => self.lower(),
        }
    }
}

pub fn unknown_device() -> String {
    pick("Unknown device", "Неизвестное устройство").to_string()
}

pub fn request_title() -> &'static str {
    pick("Receive with Quick Share?", "Принять через Quick Share?")
}

pub fn request_body(device: &str, items: &Items) -> String {
    fill(pick("{} is sharing {} with you.", "{} хочет отправить вам {}."), &[device, &items.lower()])
}

pub fn request_wifi(device: &str) -> String {
    fill(pick("{} is sharing a Wi-Fi network with you", "{} хочет поделиться с вами сетью Wi-Fi"), &[device])
}

pub fn connection_id(pin: &str) -> String {
    fill(pick("Secure connection ID: {}", "Код безопасного подключения: {}"), &[pin])
}

pub fn accept() -> &'static str {
    pick("Accept", "Принять")
}

pub fn decline() -> &'static str {
    pick("Decline", "Отклонить")
}

pub fn receiving(items: &Items, device: &str) -> String {
    fill(pick("Receiving {} from {}", "Получаем {} от {}"), &[&items.lower(), device])
}

pub fn receiving_wifi() -> &'static str {
    pick("Receiving Wi-Fi network", "Получаем сеть Wi-Fi")
}

pub fn sending(items: &Items, device: &str) -> String {
    fill(pick("Sending {} to {}", "Отправляем {} на {}"), &[&items.lower(), device])
}

pub fn waiting(device: &str) -> String {
    fill(pick("Waiting for {} to accept", "Ждём, пока {} примет"), &[device])
}

pub fn received(items: &Items, device: &str) -> String {
    if russian() {
        return fill("Получено от {}: {}", &[device, &items.noun()]);
    }
    fill("{} received from {}", &[&items.noun(), device])
}

pub fn sent(items: &Items, device: &str) -> String {
    if russian() {
        return fill("Отправлено на {}: {}", &[device, &items.noun()]);
    }
    fill("{} sent to {}", &[&items.noun(), device])
}

pub fn receive_failed(items: &Items, device: &str) -> String {
    fill(pick("Failed to receive {} from {}", "Не удалось получить {} от {}"), &[&items.lower(), device])
}

pub fn send_failed(items: &Items, device: &str) -> String {
    fill(pick("Failed to send {} to {}", "Не удалось отправить {} на {}"), &[&items.lower(), device])
}

pub fn did_not_accept() -> &'static str {
    pick(
        "The device you're trying to share with did not accept",
        "Устройство, на которое вы отправляете, не приняло передачу",
    )
}

pub fn sender_cancelled(device: &str) -> String {
    fill(pick("{} cancelled the transfer", "{} отменяет передачу"), &[device])
}

pub fn something_wrong() -> &'static str {
    pick("Something went wrong. Please try again.", "Что-то пошло не так. Попробуйте ещё раз.")
}

pub fn wifi_received(ssid: &str, device: &str) -> String {
    fill(pick("Wi-Fi network '{}' from {}", "Сеть Wi-Fi «{}» от {}"), &[ssid, device])
}

pub fn open() -> &'static str {
    pick("Open", "Открыть")
}

pub fn open_folder() -> &'static str {
    pick("Open folder", "Открыть папку")
}

pub fn copy() -> &'static str {
    pick("Copy to clipboard", "Копировать")
}

pub fn connect() -> &'static str {
    pick("Connect", "Подключиться")
}

pub fn nearby_title() -> &'static str {
    pick("Device nearby is sharing", "Устройство рядом делится файлами")
}

pub fn nearby_body() -> &'static str {
    pick(
        "To receive and accept files with people around you, become visible",
        "Чтобы получать файлы от людей рядом, станьте видимым",
    )
}

pub fn enable() -> &'static str {
    pick("Enable", "Включить")
}

pub fn dismiss() -> &'static str {
    pick("Dismiss", "Закрыть")
}

pub fn never() -> &'static str {
    pick("Don't ask again", "Больше не спрашивать")
}

pub fn app_name() -> &'static str {
    "Quick Share"
}
