    property bool activatedInCalamares: false
    property int auditStage: 0
    property string auditChangeText: qsTr("Change", "@button")
    property string auditLanguageStatus: config.currentLanguageStatus
    function auditRequire(ok: bool, message: string): void {
        if (!ok) {
            console.error("KERNORA_LANGUAGE_FAIL: " + message);
            auditTimer.stop();
            throw new Error(message);
        }
    }
    Timer {
        id: auditTimer
        interval: 600
        repeat: true
        running: activatedInCalamares && ViewManager.currentStepIndex === 1 && auditStage < 3
        onTriggered: {
            switch (auditStage) {
            case 0:
                auditRequire(config.currentLanguageCode.startsWith("en"), "Welcome language did not reach target locale");
                auditRequire(auditChangeText === "Change", "Location English text");
                config.setCurrentLocation("America", "New_York");
                config.currentLCCode = "de_DE.UTF-8";
                config.currentLanguageCode = "ru_RU.UTF-8";
                break;
            case 1:
                auditRequire(auditChangeText === "Изменить", "Location page did not retranslate after changing its language");
                auditRequire(auditLanguageStatus.startsWith("Системным языком"), "Translated C++ status did not refresh");
                auditRequire(config.currentLanguageCode === "ru_RU.UTF-8", "Explicit target locale was replaced by translation locale");
                auditRequire(config.currentLCCode === "de_DE.UTF-8", "Language change overwrote number/date formats");
                auditRequire(locationPage.cities.some(city => city.key === "New_York" && city.name.includes("Нью")), "City list did not refresh its translations");
                console.log("KERNORA_LANGUAGE_CHECK: location Russian, translated cities and independent German formats");
                ViewManager.back();
                break;
            case 2:
                auditRequire(config.currentLanguageCode.startsWith("en"), "Going back to welcome did not replace explicit target language");
                auditRequire(config.currentLCCode === "de_DE.UTF-8", "Back navigation lost explicit formats");
                auditRequire(auditChangeText === "Change", "Location did not return to English");
                finalAudit.start();
                ViewManager.next();
                break;
            }
            ++auditStage;
        }
    }
    Timer {
        id: finalAudit
        interval: 600
        onTriggered: {
            const locale = Global.value("localeConf");
            auditRequire(locale.LANG.startsWith("en"), "Final target LANG is inconsistent with selection");
            auditRequire(locale.LC_TIME === "de_DE.UTF-8", "Final target LC_TIME lost explicit formats");
            console.log("KERNORA_LANGUAGE_SMOKE_PASS: " + JSON.stringify(locale));
        }
    }
