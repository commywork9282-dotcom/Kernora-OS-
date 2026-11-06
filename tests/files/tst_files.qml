import QtQuick
import QtTest
import org.kernora.system
import "file:/usr/share/kernora/files" as FileManager
import "file:/usr/share/kernora/filechooser" as FileChooser

Item {
    width: 1120
    height: 780
    Component { id: windowComponent; FileManager.Main {} }
    Component { id: chooserComponent; FileChooser.Chooser {} }
    TestCase {
        id: tests
        name: "FilesInteractions"
        when: windowShown
        property var scene
        property var view
        function url(path) { return String(fixture.root) + (path ? "/" + path.split("/").map(encodeURIComponent).join("/") : ""); }
        function ready() { tryVerify(() => scene.folderReady, 4000); tryVerify(() => scene.pendingTabState === null, 4000); wait(100); }
        function row(path) { const index = view.model.indexOf(url(path)); verify(index >= 0, path); return index; }
        function tile(path) {
            const index = row(path);
            view.positionViewAtIndex(index, GridView.Contain);
            tryVerify(() => view.itemAtIndex(index) !== null);
            return view.itemAtIndex(index);
        }
        function click(path, modifiers) { mouseClick(tile(path), 40, 36, Qt.LeftButton, modifiers || Qt.NoModifier); }
        function init() {
            fixture.reset();
            scene = createTemporaryObject(windowComponent, tests, {folder: fixture.root, width: 1120, height: 780});
            verify(scene !== null);
            view = findChild(scene, "fileView");
            verify(view !== null);
            findChild(scene, "fileViewMode").value = "grid";
            scene.requestActivate();
            ready();
            tryCompare(view.model, "count", 8);
        }
        function test_ctrl_shift_and_release() {
            click("alpha.txt");
            compare(scene.selectedCount, 1);
            click("bravo.txt", Qt.ControlModifier);
            compare(scene.selectedCount, 2);
            click("café # 100%.txt", Qt.ShiftModifier);
            compare(scene.selectedCount, 2);
            verify(scene.isSelected(url("bravo.txt")));
            verify(scene.isSelected(url("café # 100%.txt")));
            click("bravo.txt");
            compare(scene.selectedCount, 1);
            click("A");
            click("C", Qt.ShiftModifier);
            compare(scene.selectedCount, row("C") - row("A") + 1);
        }
        function test_keyboard_selection() {
            click("A");
            fixture.key(view, Qt.Key_Right, Qt.ShiftModifier);
            compare(scene.selectedCount, 2);
            fixture.key(view, Qt.Key_Right, Qt.ControlModifier);
            compare(scene.selectedCount, 2);
            keyClick(Qt.Key_Space, Qt.ControlModifier);
            compare(scene.selectedCount, 3);
            fixture.key(view, Qt.Key_Escape, Qt.NoModifier);
            compare(scene.selectedCount, 0);
        }
        function test_checkboxes_and_mode() {
            const checkbox = findChild(tile("alpha.txt"), "fileSelection");
            scene.selectionMode = true;
            mouseClick(checkbox);
            compare(scene.selectedCount, 1);
            click("bravo.txt");
            compare(scene.selectedCount, 2);
            click("alpha.txt");
            compare(scene.selectedCount, 1);
            compare(String(scene.folder), String(fixture.root));
        }
        function test_tabs_history_selection_and_close() {
            click("alpha.txt");
            scene.newTab(url("A"), false);
            ready();
            compare(scene.tabs.length, 2);
            scene.go(url("A/Inside"));
            ready();
            scene.switchTab(0);
            ready();
            compare(scene.selectedCount, 1);
            verify(scene.isSelected(url("alpha.txt")));
            scene.switchTab(1);
            ready();
            compare(String(scene.folder), url("A/Inside"));
            scene.back();
            ready();
            compare(String(scene.folder), url("A"));
            scene.newTab(url("B"), true);
            compare(scene.activeTab, 1);
            compare(scene.tabs.length, 3);
            scene.closeTab(0);
            compare(scene.activeTab, 0);
            compare(String(scene.folder), url("A"));
            scene.closeTab(0);
            ready();
            compare(scene.tabs.length, 1);
            compare(String(scene.folder), url("B"));
        }
        function test_rapid_tab_switching_keeps_selection() {
            click("alpha.txt");
            scene.newTab(url("A/Inside"), false); ready();
            scene.newTab(url("B"), false); ready();
            for (let i = 0; i < 12; ++i) scene.switchTab(i % 3);
            scene.switchTab(0); ready();
            compare(scene.selectedCount, 1);
            verify(scene.isSelected(url("alpha.txt")));
            compare(view.model.count, 8);
        }
        function test_same_folder_tabs_keep_independent_selection() {
            click("alpha.txt");
            scene.newTab(scene.folder, false);
            ready();
            compare(scene.selectedCount, 0);
            click("bravo.txt");
            scene.switchTab(0);
            ready();
            verify(scene.isSelected(url("alpha.txt")));
            verify(!scene.isSelected(url("bravo.txt")));
            scene.switchTab(1);
            ready();
            verify(scene.isSelected(url("bravo.txt")));
        }
        function test_tab_scroll_and_shortcuts() {
            scene.go(url("Many")); ready();
            view.contentY = 600;
            const scroll = view.contentY;
            keyClick(Qt.Key_T, Qt.ControlModifier); ready();
            compare(scene.tabs.length, 2);
            keyClick(Qt.Key_Tab, Qt.ControlModifier); ready();
            compare(scene.activeTab, 0);
            verify(Math.abs(view.contentY - scroll) < 3);
            keyClick(Qt.Key_W, Qt.ControlModifier); ready();
            compare(scene.tabs.length, 1);
        }
        function test_middle_click_folder() {
            mouseClick(tile("A"), 40, 36, Qt.MiddleButton);
            compare(scene.tabs.length, 2);
            compare(scene.activeTab, 0);
            compare(scene.tabs[1].folder, url("A"));
        }
        function test_rubber_band_selection() {
            const background = findChild(scene, "selectionRectangle");
            verify(background !== null);
            mouseDrag(background, view.width / 2, view.height - 120, -view.width / 2 + 20, -view.height + 125, Qt.LeftButton, Qt.NoModifier, 500);
            verify(scene.selectedCount >= 3, "Rectangle should select files");
        }
        function transfer(paths, target, move, choice) {
            let done = false;
            let result = false;
            let error = "";
            Files.transfer(paths.map(url), url(target), move, choice || "", (ok, message) => { result = ok; error = message; done = true; });
            tryVerify(() => done, 15000);
            verify(result, error);
        }
        function test_copy_move_encoded_multifile() {
            transfer(["alpha.txt", "café # 100%.txt"], "C", false);
            compare(fixture.read("C/alpha.txt"), "alpha.txt");
            compare(fixture.read("C/café # 100%.txt"), "café # 100%.txt");
            verify(Files.exists(url("alpha.txt")));
            transfer(["alpha.txt", "bravo.txt"], "B", true);
            verify(!Files.exists(url("alpha.txt")));
            verify(!Files.exists(url("bravo.txt")));
            compare(fixture.read("B/alpha.txt"), "alpha.txt");
            compare(fixture.read("B/bravo.txt"), "bravo.txt");
        }
        function test_collision_keep_both_replace_and_same_folder() {
            transfer(["A/same.txt"], "B", false, "rename");
            compare(fixture.read("B/same.txt"), "B/same.txt");
            verify(Files.exists(url("B/same (1).txt")));
            transfer(["A/same.txt"], "B", false, "replace");
            compare(fixture.read("B/same.txt"), "A/same.txt");
            transfer(["alpha.txt"], "", false, "rename");
            verify(Files.exists(url("alpha (1).txt")));
            transfer(["alpha.txt"], "", true);
            compare(fixture.read("alpha.txt"), "alpha.txt");
        }
        function test_reject_descendant_symlink_missing_remote_and_trash() {
            verify(Files.transferError(["file:///"], url("C")).length > 0);
            verify(Files.transferError([url("A")], url("A/Inside")).length > 0);
            verify(Files.transferError([url("A")], url("alias")).length > 0);
            verify(Files.transferError([url("A")], url("A")).length > 0);
            verify(Files.transferError([url("missing")], url("B")).length > 0);
            verify(Files.transferError(["https://example.org/file"], url("B")).length > 0);
            verify(Files.transferError([url("alpha.txt")], "https://example.org/").length > 0);
            verify(Files.transferError([url("alpha.txt")], Files.trashFolder()).length > 0);
            verify(Files.transferError([url("A"), url("A/same.txt")], url("C")).length > 0);
            compare(Files.transferError([url("alpha.txt")], url("B")), "");
        }
        function test_native_drop_menu_cancel_and_destination_snapshot() {
            verify(fixture.drop(tile("B"), [url("alpha.txt"), url("bravo.txt")], Qt.CopyAction | Qt.MoveAction));
            const menu = findChild(scene, "dropChoice");
            verify(menu !== null);
            verify(menu.visible);
            compare(menu.target, url("B"));
            compare(menu.urls.length, 2);
            menu.close();
            verify(!Files.exists(url("B/alpha.txt")));
            verify(fixture.drop(tile("B"), [url("alpha.txt")], Qt.CopyAction));
            verify(!menu.canMove);
            const target = menu.target;
            const urls = menu.urls;
            menu.close();
            scene.go(url("C")); ready();
            scene.transferFiles(urls, target, false);
            tryVerify(() => Files.exists(url("B/alpha.txt")), 15000);
            verify(!Files.exists(url("C/alpha.txt")));
        }
        function test_native_drop_reject_self_and_move_only() {
            verify(!fixture.drop(tile("A"), [url("A")], Qt.CopyAction | Qt.MoveAction));
            verify(!fixture.drop(tile("B"), [url("alpha.txt")], Qt.MoveAction));
            verify(!Files.exists(url("B/alpha.txt")));
        }
        function test_file_chooser_shared_delegate_compatibility() {
            const chooser = createTemporaryObject(chooserComponent, tests, {folder: fixture.root, startFolder: fixture.root, folderGiven: true, visible: true});
            verify(chooser !== null);
            function findGrid(item) {
                if (String(item).indexOf("QQuickGridView") >= 0) return item;
                for (const child of item.children || []) {
                    const grid = findGrid(child);
                    if (grid) return grid;
                }
                return null;
            }
            const grid = findGrid(chooser.contentItem);
            verify(grid !== null);
            tryCompare(grid.model, "count", 8);
            const index = grid.model.indexOf(url("alpha.txt"));
            grid.positionViewAtIndex(index, GridView.Contain);
            tryVerify(() => grid.itemAtIndex(index) !== null);
            const item = grid.itemAtIndex(index);
            verify(!item.selectionEnabled);
            verify(!item.dragEnabled);
            verify(!item.dropEnabled);
            let answer = null;
            chooser.finished.connect(result => answer = result);
            mouseClick(item, 40, 36);
            compare(chooser.selectedCount, 1);
            chooser.accept();
            verify(answer !== null && answer.accepted);
            compare(String(answer.uris[0]), url("alpha.txt"));
        }
        function test_same_folder_tabs_with_different_filters() {
            const search = findChild(scene, "fileSearch");
            search.text = "alpha";
            tryCompare(view.model, "count", 6);
            click("alpha.txt");
            scene.newTab(scene.folder, false); ready();
            search.text = "bravo";
            tryCompare(view.model, "count", 6);
            click("bravo.txt");
            for (let i = 0; i < 4; ++i) {
                scene.switchTab(i % 2); ready();
                const wanted = i % 2 === 0 ? "alpha" : "bravo";
                compare(search.text, wanted);
                verify(scene.isSelected(url(wanted + ".txt")));
                compare(scene.selectedCount, 1);
            }
        }
        function test_list_selection_and_filter_per_tab() {
            const mode = findChild(scene, "fileViewMode");
            mode.value = "list";
            wait(150);
            click("A");
            click("C", Qt.ShiftModifier);
            compare(scene.selectedCount, row("C") - row("A") + 1);
            const search = findChild(scene, "fileSearch");
            search.text = "alpha";
            tryCompare(view.model, "count", 6);
            compare(view.model.indexOf(url("bravo.txt")), -1);
            scene.newTab(url("B"), false); ready();
            compare(search.text, "");
            scene.switchTab(0); ready();
            compare(search.text, "alpha");
            compare(view.model.count, 6);
            compare(view.model.indexOf(url("bravo.txt")), -1);
            mode.value = "grid";
        }
        function test_conflict_cancel_preserves_cut_clipboard() {
            scene.go(url("A")); ready();
            click("A/same.txt");
            scene.copy(true);
            scene.go(url("B")); ready();
            scene.paste();
            const dialog = findChild(scene, "fileConflict");
            tryCompare(dialog, "visible", true);
            dialog.close();
            verify(Files.exists(url("A/same.txt")));
            compare(scene.clipboard.urls.length, 1);
            scene.paste();
            tryCompare(dialog, "visible", true);
            scene.resolveConflict("skip");
            verify(Files.exists(url("A/same.txt")));
            compare(fixture.read("B/same.txt"), "B/same.txt");
            scene.paste();
            tryCompare(dialog, "visible", true);
            scene.resolveConflict("rename");
            tryVerify(() => !Files.exists(url("A/same.txt")), 15000);
            compare(fixture.read("B/same (1).txt"), "A/same.txt");
            tryCompare(scene, "operations", 0, 15000);
            compare(scene.clipboard.urls.length, 0);
        }
        function test_z_screenshots() {
            scene.newTab(url("A"), true);
            scene.newTab(url("B"), true);
            click("alpha.txt");
            click("bravo.txt", Qt.ControlModifier);
            scene.selectionMode = true;
            wait(600);
            grabImage(scene.contentItem).save("/tmp/files-tabs-selection.png");
            verify(fixture.drop(tile("B"), [url("alpha.txt"), url("bravo.txt")], Qt.CopyAction | Qt.MoveAction));
            wait(250);
            grabImage(scene.contentItem).save("/tmp/files-drop-choice.png");
        }
    }
}
