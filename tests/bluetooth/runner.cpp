#include <QtQuickTest/quicktest.h>
#include <QQmlEngine>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

class Setup : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        KLocalizedString::setApplicationDomain("kernora-settings");
        KLocalization::setupLocalizedContext(engine);
    }
};

QUICK_TEST_MAIN_WITH_SETUP(bluetooth, Setup)
#include "runner.moc"
