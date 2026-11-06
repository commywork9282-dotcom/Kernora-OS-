#!/usr/bin/python3
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ADAPTER = "org.bluez.Adapter1"
DEVICE = "org.bluez.Device1"
PROPERTIES = "org.freedesktop.DBus.Properties"
CONTROL = "org.kernora.BluetoothTest"


class Properties(dbus.service.Object):
    def __init__(self, server, path, interface, properties):
        self.server = server
        self.interface = interface
        self.properties = properties
        self.path = path
        super().__init__(server.bus, path)

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.properties if interface == self.interface else {}

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.properties[name]

    @dbus.service.method(PROPERTIES, in_signature="ssv", out_signature="")
    def Set(self, interface, name, value):
        self.update({name: value})

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def update(self, changed):
        self.properties.update(changed)
        self.PropertiesChanged(self.interface, changed, [])


class Adapter(Properties):
    def __init__(self, server, name):
        self.sessions = set()
        super().__init__(server, "/org/bluez/" + name, ADAPTER, {
            "Address": "00:11:22:33:44:55", "AddressType": "public", "Name": "Test adapter", "Alias": "Test adapter",
            "Powered": dbus.Boolean(True), "Discovering": dbus.Boolean(False), "Discoverable": dbus.Boolean(False),
            "Pairable": dbus.Boolean(True), "DiscoverableTimeout": dbus.UInt32(0), "PairableTimeout": dbus.UInt32(0),
            "Class": dbus.UInt32(0), "UUIDs": dbus.Array([], signature="s"), "Modalias": "",
        })

    @dbus.service.method(ADAPTER, in_signature="", out_signature="", sender_keyword="sender", async_callbacks=("reply", "error"))
    def StartDiscovery(self, reply, error, sender=None):
        self.server.starts += 1
        if self.server.fail_next:
            self.server.fail_next = False
            error(dbus.exceptions.DBusException("Test start failure", name="org.bluez.Error.Failed"))
            return
        if self.server.delay:
            self.server.pending.append((self, sender, reply, error))
        else:
            self.complete(sender, reply)

    def complete(self, sender, reply):
        if self.server.bus.name_has_owner(sender):
            self.sessions.add(sender)
            self.refresh()
            reply()

    def refresh(self):
        self.update({"Discovering": dbus.Boolean(bool(self.sessions) or self.server.external)})

    @dbus.service.method(ADAPTER, in_signature="", out_signature="", sender_keyword="sender")
    def StopDiscovery(self, sender=None):
        self.server.stops += 1
        if sender not in self.sessions:
            raise dbus.exceptions.DBusException("No session owned by this client", name="org.bluez.Error.NotAuthorized")
        self.sessions.remove(sender)
        self.refresh()


class Device(Properties):
    def __init__(self, server, address, name, alias):
        properties = {"Address": address, "AddressType": "public", "Alias": alias or address.replace(":", "-"),
                      "Adapter": dbus.ObjectPath("/org/bluez/hci0"), "Paired": dbus.Boolean(False),
                      "Connected": dbus.Boolean(False), "Trusted": dbus.Boolean(False), "Blocked": dbus.Boolean(False),
                      "ServicesResolved": dbus.Boolean(False), "LegacyPairing": dbus.Boolean(False),
                      "RSSI": dbus.Int16(-50), "Class": dbus.UInt32(0), "Appearance": dbus.UInt16(0),
                      "UUIDs": dbus.Array([], signature="s"), "Icon": "audio-headphones"}
        if name:
            properties["Name"] = name
        super().__init__(server, "/org/bluez/hci0/dev_" + address.replace(":", "_"), DEVICE, properties)

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def Pair(self):
        self.server.pairs += 1
        self.server.last_paired = str(self.properties["Address"])
        self.update({"Paired": dbus.Boolean(True)})

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def Connect(self):
        self.update({"Connected": dbus.Boolean(True)})

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def Disconnect(self):
        self.update({"Connected": dbus.Boolean(False)})


class Server(dbus.service.Object):
    def __init__(self, bus):
        self.bus = bus
        self.objects = {}
        self.reset_state()
        self.name = dbus.service.BusName("org.bluez", bus=bus)
        super().__init__(self.name, "/")
        bus.add_signal_receiver(self.owner_changed, signal_name="NameOwnerChanged", dbus_interface="org.freedesktop.DBus")

    def reset_state(self):
        self.starts = self.stops = self.pairs = 0
        self.last_paired = ""
        self.delay = self.fail_next = self.external = False
        self.pending = []

    def owner_changed(self, name, old, new):
        if new:
            return
        self.pending = [call for call in self.pending if call[1] != name]
        for obj in self.objects.values():
            if isinstance(obj, Adapter) and name in obj.sessions:
                obj.sessions.remove(name)
                obj.refresh()

    @dbus.service.method("org.freedesktop.DBus.ObjectManager", in_signature="", out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        objects = {dbus.ObjectPath(path): {obj.interface: obj.properties} for path, obj in self.objects.items()}
        objects[dbus.ObjectPath("/org/bluez")] = {"org.bluez.AgentManager1": {}, "org.bluez.ProfileManager1": {}}
        return objects

    @dbus.service.signal("org.freedesktop.DBus.ObjectManager", signature="oa{sa{sv}}")
    def InterfacesAdded(self, path, interfaces):
        pass

    @dbus.service.signal("org.freedesktop.DBus.ObjectManager", signature="oas")
    def InterfacesRemoved(self, path, interfaces):
        pass

    def add(self, obj):
        self.objects[obj.path] = obj
        self.InterfacesAdded(dbus.ObjectPath(obj.path), {obj.interface: obj.properties})

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def Reset(self):
        for path, obj in list(self.objects.items()):
            self.InterfacesRemoved(dbus.ObjectPath(path), [obj.interface])
            obj.remove_from_connection()
        self.objects.clear()
        for obj, sender, reply, error in self.pending:
            if self.bus.name_has_owner(sender):
                error(dbus.exceptions.DBusException("Adapter removed", name="org.bluez.Error.NotReady"))
        self.reset_state()

    @dbus.service.method(CONTROL, in_signature="s", out_signature="")
    def AddAdapter(self, name):
        self.add(Adapter(self, str(name)))

    @dbus.service.method(CONTROL, in_signature="sss", out_signature="")
    def AddDevice(self, address, name, alias):
        self.add(Device(self, str(address), str(name), str(alias)))

    def device(self, address):
        return self.objects["/org/bluez/hci0/dev_" + str(address).replace(":", "_")]

    @dbus.service.method(CONTROL, in_signature="ss", out_signature="")
    def UpdateName(self, address, name):
        self.device(address).update({"Name": str(name)})

    @dbus.service.method(CONTROL, in_signature="ss", out_signature="")
    def SetAlias(self, address, name):
        self.device(address).update({"Alias": str(name)})

    @dbus.service.method(CONTROL, in_signature="ss", out_signature="")
    def SetRssi(self, address, value):
        self.device(address).update({"RSSI": dbus.Int16(int(value))})

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def SetPowered(self, powered):
        adapter = self.objects["/org/bluez/hci0"]
        if not powered:
            adapter.sessions.clear()
        adapter.update({"Powered": dbus.Boolean(powered)})
        adapter.refresh()

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def ExternalDiscovery(self, enabled):
        self.external = bool(enabled)
        for obj in self.objects.values():
            if isinstance(obj, Adapter):
                obj.refresh()

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def DelayStart(self, enabled):
        self.delay = bool(enabled)

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def ReleasePending(self):
        pending, self.pending = self.pending, []
        for adapter, sender, reply, error in pending:
            adapter.complete(sender, reply)

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def FailNextStart(self):
        self.fail_next = True

    @dbus.service.method(CONTROL, in_signature="", out_signature="a{sv}")
    def Counts(self):
        sessions = sum(len(obj.sessions) for obj in self.objects.values() if isinstance(obj, Adapter))
        return {"starts": dbus.Int32(self.starts), "stops": dbus.Int32(self.stops), "sessions": dbus.Int32(sessions),
                "pending": dbus.Int32(len(self.pending)), "external": dbus.Boolean(self.external),
                "pairs": dbus.Int32(self.pairs), "lastPaired": self.last_paired}


DBusGMainLoop(set_as_default=True)
server = Server(dbus.SessionBus())
GLib.MainLoop().run()
