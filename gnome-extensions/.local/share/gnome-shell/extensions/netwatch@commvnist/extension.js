import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const UPDATE_INTERVAL_SECONDS = 2;
const PRIVATE_IP_PREFIX = '192.168.2.';

const NetwatchIndicator = GObject.registerClass(
class NetwatchIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Netwatch', false);

        this._previousSample = null;
        this._fields = {};
        this._box = new St.BoxLayout({
            style_class: 'netwatch-panel',
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._addText('ipLabel', 'IP', 'netwatch-label');
        this._addValue('ip', '---.---.---.---', 'netwatch-value-ip netwatch-dim');
        this._addSeparator();
        this._addText('downLabel', 'DN', 'netwatch-label');
        this._addValue('down', ' --.-K', 'netwatch-value-speed netwatch-dim');
        this._addSeparator();
        this._addText('upLabel', 'UP', 'netwatch-label');
        this._addValue('up', ' --.-K', 'netwatch-value-speed netwatch-dim');

        this.add_child(this._box);
    }

    refresh() {
        try {
            const sample = readNetworkSample();
            const ipAddress = readLocalIpAddress();
            const speeds = calculateSpeeds(this._previousSample, sample);

            this._previousSample = sample;
            this._setField('ip', formatIpAddress(ipAddress), ipAddress === null ? 'netwatch-dim' : 'netwatch-blue');
            this._setField('down', formatSpeed(speeds.downBytesPerSecond), speedClass(speeds.downBytesPerSecond));
            this._setField('up', formatSpeed(speeds.upBytesPerSecond), speedClass(speeds.upBytesPerSecond));
        } catch (error) {
            logError(error, 'netwatch: failed to refresh network stats');
            this._setField('ip', '---.---.---.---', 'netwatch-dim');
            this._setField('down', ' --.-K', 'netwatch-dim');
            this._setField('up', ' --.-K', 'netwatch-dim');
        }
    }

    _addText(name, text, styleClass) {
        const label = new St.Label({
            text,
            style_class: styleClass,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._fields[name] = label;
        this._box.add_child(label);
    }

    _addValue(name, text, styleClass) {
        const label = new St.Label({
            text,
            style_class: styleClass,
            y_align: Clutter.ActorAlign.CENTER,
            x_align: Clutter.ActorAlign.END,
        });
        this._fields[name] = label;
        this._box.add_child(label);
    }

    _addSeparator() {
        const separator = new St.Label({
            text: '|',
            style_class: 'netwatch-separator',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._box.add_child(separator);
    }

    _setField(name, text, statusClass) {
        const label = this._fields[name];
        if (label === undefined)
            return;

        const fixedClass = label.style_class
            .split(/\s+/)
            .find(styleClass => styleClass.startsWith('netwatch-value-'));

        label.text = text;
        label.style_class = `${fixedClass} ${statusClass}`;
    }
});

export default class NetwatchExtension extends Extension {
    enable() {
        this._indicator = new NetwatchIndicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator, 1, 'left');

        this._indicator.refresh();
        this._timerId = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT,
            UPDATE_INTERVAL_SECONDS,
            () => {
                this._indicator.refresh();
                return GLib.SOURCE_CONTINUE;
            });
    }

    disable() {
        if (this._timerId) {
            GLib.Source.remove(this._timerId);
            this._timerId = 0;
        }

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}

function readNetworkSample() {
    const netdev = readFileText('/proc/net/dev');
    let receiveBytes = 0;
    let transmitBytes = 0;

    for (const line of netdev.split('\n')) {
        const match = line.match(/^\s*([^:]+):\s*(.*)$/);
        if (match === null)
            continue;

        const interfaceName = match[1].trim();
        if (shouldIgnoreInterface(interfaceName))
            continue;

        const fields = match[2].trim().split(/\s+/).map(value => Number.parseInt(value, 10));
        if (fields.length < 16 || fields.some(value => Number.isNaN(value)))
            continue;

        receiveBytes += fields[0];
        transmitBytes += fields[8];
    }

    return {
        timeUs: GLib.get_monotonic_time(),
        receiveBytes,
        transmitBytes,
    };
}

function calculateSpeeds(previousSample, currentSample) {
    if (previousSample === null)
        return {downBytesPerSecond: null, upBytesPerSecond: null};

    const elapsedSeconds = (currentSample.timeUs - previousSample.timeUs) / 1000000;
    if (elapsedSeconds <= 0)
        return {downBytesPerSecond: null, upBytesPerSecond: null};

    const receiveDelta = currentSample.receiveBytes - previousSample.receiveBytes;
    const transmitDelta = currentSample.transmitBytes - previousSample.transmitBytes;
    if (receiveDelta < 0 || transmitDelta < 0)
        return {downBytesPerSecond: null, upBytesPerSecond: null};

    return {
        downBytesPerSecond: receiveDelta / elapsedSeconds,
        upBytesPerSecond: transmitDelta / elapsedSeconds,
    };
}

function shouldIgnoreInterface(interfaceName) {
    return interfaceName === 'lo'
        || interfaceName.startsWith('docker')
        || interfaceName.startsWith('br-')
        || interfaceName.startsWith('veth')
        || interfaceName.startsWith('virbr')
        || interfaceName.startsWith('tailscale')
        || interfaceName.startsWith('zt');
}

function readLocalIpAddress() {
    const addresses = readIpv4Addresses();
    const privateAddress = addresses.find(address => address.startsWith(PRIVATE_IP_PREFIX));

    if (privateAddress !== undefined)
        return privateAddress;

    return addresses[0] ?? null;
}

function readIpv4Addresses() {
    const addresses = [];
    const output = readFileText('/proc/net/fib_trie');
    let candidate = null;

    for (const line of output.split('\n')) {
        const ipMatch = line.match(/[+|]--\s+(\d+\.\d+\.\d+\.\d+)/);
        if (ipMatch !== null) {
            candidate = ipMatch[1];
            continue;
        }

        if (candidate === null || !line.includes('/32 host LOCAL'))
            continue;
        if (!candidate.startsWith('127.'))
            addresses.push(candidate);
        candidate = null;
    }

    return [...new Set(addresses)];
}

function readFileText(path) {
    try {
        const [, contents] = GLib.file_get_contents(path);
        return new TextDecoder().decode(contents).trim();
    } catch (error) {
        return '';
    }
}

function formatIpAddress(ipAddress) {
    if (ipAddress === null)
        return '---.---.---.---';

    return ipAddress.padStart(15, ' ');
}

function formatSpeed(bytesPerSecond) {
    if (bytesPerSecond === null)
        return ' --.-K';

    const kibPerSecond = bytesPerSecond / 1024;
    if (kibPerSecond < 1000)
        return `${kibPerSecond.toFixed(1).padStart(5, ' ')}K`;

    const mibPerSecond = kibPerSecond / 1024;
    if (mibPerSecond < 100)
        return `${mibPerSecond.toFixed(1).padStart(5, ' ')}M`;

    return `${Math.min(Math.round(mibPerSecond), 9999).toString().padStart(5, ' ')}M`;
}

function speedClass(bytesPerSecond) {
    if (bytesPerSecond === null)
        return 'netwatch-dim';

    const kibPerSecond = bytesPerSecond / 1024;
    if (kibPerSecond < 100)
        return 'netwatch-green';
    if (kibPerSecond < 1024)
        return 'netwatch-yellow';
    if (kibPerSecond < 10240)
        return 'netwatch-orange';
    return 'netwatch-red';
}
