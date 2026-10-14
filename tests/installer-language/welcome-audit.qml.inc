    property bool activatedInCalamares: false
    property int auditStage: 0
    property int auditTicks: 0
    Instantiator {
        id: auditLanguages
        model: config.languagesModel
        delegate: QtObject {
            required property int index
            required property string englishLabel
        }
    }
    Instantiator {
        id: auditSteps
        model: ViewManager
        delegate: QtObject {
            required property int index
            required property string display
        }
    }
    function auditIndex(language: string): int {
        for (let i = 0; i < auditLanguages.count; ++i) {
            if (auditLanguages.objectAt(i).englishLabel.startsWith(language)) {
                return i;
            }
        }
        throw new Error("Translation not found: " + language);
    }
    function auditRequire(ok: bool, message: string): void {
        if (!ok) {
            console.error("KERNORA_LANGUAGE_FAIL: " + message + " | " + welcomeText);
            auditTimer.stop();
            throw new Error(message);
        }
    }
    Timer {
        id: auditTimer
        interval: 600
        repeat: true
        running: activatedInCalamares && ViewManager.currentStepIndex === 0 && auditStage < 7
        onTriggered: {
            ++auditTicks;
            auditRequire(auditTicks < 40, "Welcome timeout");
            if (!ViewManager.nextEnabled || auditLanguages.count === 0) {
                return;
            }
            switch (auditStage) {
            case 0:
                config.localeIndex = auditIndex("English");
                break;
            case 1:
                auditRequire(welcomeText.includes("Welcome"), "Initial English text");
                config.localeIndex = auditIndex("Russian");
                break;
            case 2:
                auditRequire(welcomeText.includes("Добро пожаловать"), "English to Russian did not retranslate welcome");
                auditRequire(auditSteps.objectAt(0).display === "Добро пожаловать", "Russian sidebar did not refresh");
                console.log("KERNORA_LANGUAGE_CHECK: welcome Russian | " + ViewManager.nextLabel);
                config.localeIndex = auditIndex("German");
                break;
            case 3:
                auditRequire(welcomeText.includes("Willkommen"), "Russian to German did not retranslate welcome");
                auditRequire(auditSteps.objectAt(0).display === "Willkommen", "German sidebar did not refresh");
                console.log("KERNORA_LANGUAGE_CHECK: welcome German | " + ViewManager.nextLabel);
                config.localeIndex = auditIndex("English");
                break;
            case 4:
                auditRequire(welcomeText.includes("Welcome"), "German to English did not retranslate welcome");
                auditRequire(auditSteps.objectAt(0).display === "Welcome", "English sidebar did not refresh");
                ViewManager.next();
                break;
            case 5:
                auditRequire(config.localeIndex === auditIndex("Russian"), "Welcome selector did not follow location language");
                auditRequire(welcomeText.includes("Добро пожаловать"), "Hidden welcome page did not retranslate");
                auditRequire(auditSteps.objectAt(1).display === "Местоположение", "Location choice did not refresh sidebar");
                config.localeIndex = auditIndex("English");
                break;
            case 6:
                auditRequire(welcomeText.includes("Welcome"), "Return to English on welcome");
                auditRequire(auditSteps.objectAt(0).display === "Welcome", "English sidebar did not refresh");
                ViewManager.next();
                break;
            }
            ++auditStage;
        }
    }
