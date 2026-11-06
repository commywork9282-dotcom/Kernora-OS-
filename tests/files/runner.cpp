#include <QtQuickTest/quicktest.h>
#include <QApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>
#include <QQuickItem>
#include <QQuickWindow>
#include <QMimeData>
#include <QDropEvent>
#include <QKeyEvent>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

class Fixture : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl root READ root CONSTANT)
public:
    QTemporaryDir directory;
    QUrl root() const { return QUrl::fromLocalFile(directory.path()); }
    Q_INVOKABLE void reset()
    {
        for (const QString &name : QDir(directory.path()).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden)) {
            const QString path = directory.filePath(name);
            if (QFileInfo(path).isDir() && !QFileInfo(path).isSymLink()) QDir(path).removeRecursively();
            else QFile::remove(path);
        }
        for (const QString &name : {"A/Inside", "B", "C", "Many"}) QDir().mkpath(directory.filePath(name));
        for (const QString &name : {"alpha.txt", "bravo.txt", "café # 100%.txt", "A/same.txt", "B/same.txt"}) write(name, name);
        for (int i = 0; i < 100; ++i) write(QStringLiteral("Many/file-%1.txt").arg(i, 3, 10, QLatin1Char('0')), QString::number(i));
        QFile::link(directory.filePath("A/Inside"), directory.filePath("alias"));
    }
    Q_INVOKABLE void write(const QString &name, const QString &text)
    {
        QFile file(directory.filePath(name));
        if (file.open(QIODevice::WriteOnly)) file.write(text.toUtf8());
    }
    Q_INVOKABLE QString read(const QString &name)
    {
        QFile file(directory.filePath(name));
        if (!file.open(QIODevice::ReadOnly)) return {};
        return QString::fromUtf8(file.readAll());
    }
    Q_INVOKABLE void key(QObject *object, int key, int modifiers)
    {
        QKeyEvent press(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers));
        QApplication::sendEvent(object, &press);
        QKeyEvent release(QEvent::KeyRelease, key, Qt::KeyboardModifiers(modifiers));
        QApplication::sendEvent(object, &release);
    }
    Q_INVOKABLE bool drop(QObject *object, const QList<QUrl> &urls, int actions)
    {
        auto *item = qobject_cast<QQuickItem *>(object);
        if (!item || !item->window()) return false;
        QMimeData mime;
        mime.setUrls(urls);
        const QPoint point = item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint();
        QDragEnterEvent enter(point, Qt::DropActions(actions), &mime, Qt::LeftButton, Qt::NoModifier);
        QApplication::sendEvent(item->window(), &enter);
        QDragMoveEvent move(point, Qt::DropActions(actions), &mime, Qt::LeftButton, Qt::NoModifier);
        QApplication::sendEvent(item->window(), &move);
        QDropEvent event(point, Qt::DropActions(actions), &mime, Qt::LeftButton, Qt::NoModifier);
        QApplication::sendEvent(item->window(), &event);
        return event.isAccepted() && event.dropAction() == Qt::CopyAction;
    }
};

class Setup : public QObject
{
    Q_OBJECT
public:
    Fixture fixture;
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        KLocalizedString::setApplicationDomain("kernora-files");
        KLocalization::setupLocalizedContext(engine);
        engine->rootContext()->setContextProperty(QStringLiteral("startArguments"), QStringList());
        engine->rootContext()->setContextProperty(QStringLiteral("fixture"), &fixture);
    }
};

int main(int argc, char **argv)
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "org.kernora.desktop");
    QApplication app(argc, argv);
    Setup setup;
    return quick_test_main_with_setup(argc, argv, "files", nullptr, &setup);
}
#include "runner.moc"
