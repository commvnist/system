import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const UPDATE_INTERVAL_SECONDS = 2;
const COMMAND_TIMEOUT_MS = 1500;

const TEMP_WARN = 60;
const TEMP_HOT = 75;
const TEMP_CRIT = 85;

const CPU_MAX_MHZ_FALLBACK = 5400;

const SyswatchIndicator = GObject.registerClass(
class SyswatchIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Syswatch', false);

        this._lastCpuSample = null;
        this._updateInProgress = false;
        this._lastLaunchMs = 0;

        this._fields = {};
        this._box = new St.BoxLayout({
            reactive: true,
            style_class: 'syswatch-panel',
            y_align: Clutter.ActorAlign.CENTER,
        });

        this._addText('cpuLabel', 'CPU', 'syswatch-label');
        this._addValue('cpuUsage', ' --%', 'syswatch-value-4 syswatch-dim');
        this._addValue('cpuTemp', ' --°', 'syswatch-value-4 syswatch-dim');
        this._addValue('cpuFreq', '-.-G', 'syswatch-value-4 syswatch-dim');
        this._addSeparator();
        this._addText('gpuLabel', 'GPU', 'syswatch-label');
        this._addValue('gpuUsage', ' --%', 'syswatch-value-4 syswatch-dim');
        this._addValue('gpuTemp', ' --°', 'syswatch-value-4 syswatch-dim');
        this._addSeparator();
        this._addText('ramLabel', 'RAM', 'syswatch-label');
        this._addValue('ramUsage', ' --%', 'syswatch-value-4 syswatch-dim');

        this.add_child(this._box);
        this.menu.connect('open-state-changed', (_menu, isOpen) => {
            if (!isOpen)
                return;

            this.menu.close();
            this._handleActivation();
        });
        this.connect('button-press-event', this._handleClickEvent.bind(this));
        this.connect('button-release-event', this._handleClickEvent.bind(this));
        this._box.connect('button-press-event', this._handleClickEvent.bind(this));
        this._box.connect('button-release-event', this._handleClickEvent.bind(this));
    }

    async refresh() {
        if (this._updateInProgress)
            return;

        this._updateInProgress = true;

        try {
            const stats = await this._collectStats();
            this._renderStats(stats);
        } catch (error) {
            logError(error, 'syswatch: failed to refresh panel stats');
            this._setAllDim();
        } finally {
            this._updateInProgress = false;
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
            style_class: 'syswatch-separator',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._box.add_child(separator);
    }

    async _collectStats() {
        const [sensorOutput, nvidiaOutput] = await Promise.all([
            runCommand(['sensors'], COMMAND_TIMEOUT_MS),
            runCommand([
                'nvidia-smi',
                '--query-gpu=utilization.gpu,temperature.gpu',
                '--format=csv,noheader,nounits',
            ], COMMAND_TIMEOUT_MS),
        ]);

        const cpuSample = readCpuSample();
        const stats = {
            cpuUsage: calculateCpuUsage(this._lastCpuSample, cpuSample),
            cpuTemp: readCpuPackageTemp(sensorOutput),
            cpuFreqMhz: readAverageCpuFrequencyMhz(),
            gpuUsage: null,
            gpuTemp: readThinkpadGpuTemp(sensorOutput),
            ramUsage: readRamUsage(),
        };

        this._lastCpuSample = cpuSample;

        const nvidiaStats = parseNvidiaStats(nvidiaOutput);
        if (nvidiaStats !== null) {
            stats.gpuUsage = nvidiaStats.usage;
            stats.gpuTemp = nvidiaStats.temp;
        }

        return stats;
    }

    _renderStats(stats) {
        this._setField('cpuUsage', formatPercent(stats.cpuUsage), percentClass(stats.cpuUsage));
        this._setField('cpuTemp', formatTemp(stats.cpuTemp), tempClass(stats.cpuTemp));
        this._setField('cpuFreq', formatGhz(stats.cpuFreqMhz), freqClass(stats.cpuFreqMhz));
        this._setField('gpuUsage', formatPercent(stats.gpuUsage), percentClass(stats.gpuUsage));
        this._setField('gpuTemp', formatTemp(stats.gpuTemp), tempClass(stats.gpuTemp));
        this._setField('ramUsage', formatPercent(stats.ramUsage), percentClass(stats.ramUsage));
    }

    _setField(name, text, statusClass) {
        const label = this._fields[name];
        if (label === undefined)
            return;

        const fixedClass = label.style_class
            .split(/\s+/)
            .find(styleClass => styleClass.startsWith('syswatch-value-'));

        label.text = text;
        label.style_class = `${fixedClass} ${statusClass}`;
    }

    _setAllDim() {
        this._setField('cpuUsage', ' --%', 'syswatch-dim');
        this._setField('cpuTemp', ' --°', 'syswatch-dim');
        this._setField('cpuFreq', '-.-G', 'syswatch-dim');
        this._setField('gpuUsage', ' --%', 'syswatch-dim');
        this._setField('gpuTemp', ' --°', 'syswatch-dim');
        this._setField('ramUsage', ' --%', 'syswatch-dim');
    }

    _openSyswatchTerminal() {
        const kittyPath = findExecutable('kitty', '/usr/bin/kitty');
        if (kittyPath === null) {
            Main.notify('Syswatch', 'kitty was not found in PATH.');
            return;
        }

        const zshPath = findExecutable('zsh', '/usr/bin/zsh');
        if (zshPath === null) {
            Main.notify('Syswatch', 'zsh was not found.');
            return;
        }

        const argv = [
            kittyPath,
            '--detach',
            '--title',
            'syswatch',
            zshPath,
            getLauncherScriptPath(),
        ];

        try {
            GLib.spawn_async(
                null,
                argv,
                null,
                GLib.SpawnFlags.SEARCH_PATH,
                null);
        } catch (error) {
            logError(error, 'syswatch: failed to launch kitty');
            Main.notify('Syswatch', 'Failed to launch kitty for syswatch.');
        }
    }

    _handleActivation() {
        const nowMs = GLib.get_monotonic_time() / 1000;
        if (nowMs - this._lastLaunchMs < 500)
            return;

        this._lastLaunchMs = nowMs;
        this._openSyswatchTerminal();
    }

    _handleClickEvent(_actor, event) {
        if (event.get_button() !== 1)
            return Clutter.EVENT_PROPAGATE;

        this._handleActivation();
        return Clutter.EVENT_STOP;
    }
});

export default class SyswatchExtension extends Extension {
    enable() {
        this._indicator = new SyswatchIndicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');

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

function runCommand(argv, timeoutMs) {
    return new Promise(resolve => {
        let process;
        let timeoutId = 0;

        try {
            process = Gio.Subprocess.new(
                argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (error) {
            resolve('');
            return;
        }

        timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, timeoutMs, () => {
            try {
                process.force_exit();
            } catch (error) {
                logError(error, `syswatch: failed to stop timed-out command ${argv[0]}`);
            }
            timeoutId = 0;
            return GLib.SOURCE_REMOVE;
        });

        process.communicate_utf8_async(null, null, (_process, result) => {
            if (timeoutId !== 0) {
                GLib.Source.remove(timeoutId);
                timeoutId = 0;
            }

            try {
                const [, stdout] = process.communicate_utf8_finish(result);
                resolve(stdout ?? '');
            } catch (error) {
                resolve('');
            }
        });
    });
}

function findExecutable(name, fallbackPath) {
    const path = GLib.find_program_in_path(name);
    if (path !== null)
        return path;

    if (GLib.file_test(fallbackPath, GLib.FileTest.IS_EXECUTABLE))
        return fallbackPath;

    return null;
}

function getLauncherScriptPath() {
    return GLib.build_filenamev([
        GLib.get_home_dir(),
        '.local',
        'share',
        'gnome-shell',
        'extensions',
        'syswatch@commvnist',
        'open-syswatch.zsh',
    ]);
}

function readFileText(path) {
    try {
        const [, contents] = GLib.file_get_contents(path);
        return new TextDecoder().decode(contents).trim();
    } catch (error) {
        return '';
    }
}

function readCpuSample() {
    const stat = readFileText('/proc/stat');
    const line = stat.split('\n').find(row => row.startsWith('cpu '));
    if (line === undefined)
        return null;

    const values = line.trim().split(/\s+/).slice(1).map(value => Number.parseInt(value, 10));
    if (values.some(value => Number.isNaN(value)))
        return null;

    const idle = values[3] + values[4];
    const total = values.reduce((sum, value) => sum + value, 0);
    return {idle, total};
}

function calculateCpuUsage(previousSample, currentSample) {
    if (previousSample === null || currentSample === null)
        return null;

    const idleDelta = currentSample.idle - previousSample.idle;
    const totalDelta = currentSample.total - previousSample.total;
    if (totalDelta <= 0 || idleDelta < 0)
        return null;

    return clampPercent(Math.round(((totalDelta - idleDelta) * 100) / totalDelta));
}

function readAverageCpuFrequencyMhz() {
    const cpuinfo = readFileText('/proc/cpuinfo');
    const values = [];

    for (const line of cpuinfo.split('\n')) {
        if (!line.startsWith('cpu MHz'))
            continue;

        const rawValue = line.split(':')[1]?.trim();
        const value = Number.parseFloat(rawValue);
        if (!Number.isNaN(value))
            values.push(value);
    }

    if (values.length === 0)
        return null;

    const total = values.reduce((sum, value) => sum + value, 0);
    return Math.round(total / values.length);
}

function readRamUsage() {
    const meminfo = readFileText('/proc/meminfo');
    let totalKb = null;
    let availableKb = null;

    for (const line of meminfo.split('\n')) {
        if (line.startsWith('MemTotal:'))
            totalKb = parseMeminfoKb(line);
        else if (line.startsWith('MemAvailable:'))
            availableKb = parseMeminfoKb(line);
    }

    if (totalKb === null || availableKb === null || totalKb <= 0)
        return null;

    return clampPercent(Math.round(((totalKb - availableKb) * 100) / totalKb));
}

function parseMeminfoKb(line) {
    const match = line.match(/:\s+(\d+)\s+kB/);
    if (match === null)
        return null;

    return Number.parseInt(match[1], 10);
}

function readCpuPackageTemp(sensorOutput) {
    return readSensorValue(sensorOutput, 'coretemp-isa', 'Package id 0:')
        ?? readMaxCoreTemp(sensorOutput);
}

function readMaxCoreTemp(sensorOutput) {
    let inCoretempBlock = false;
    let maxTemp = null;

    for (const line of sensorOutput.split('\n')) {
        if (line.trim() === '') {
            inCoretempBlock = false;
            continue;
        }

        if (!inCoretempBlock) {
            inCoretempBlock = line.includes('coretemp-isa');
            continue;
        }

        if (!line.includes('Core '))
            continue;

        const value = parseTemperature(line);
        if (value !== null)
            maxTemp = Math.max(maxTemp ?? value, value);
    }

    return maxTemp;
}

function readThinkpadGpuTemp(sensorOutput) {
    return readSensorValue(sensorOutput, 'thinkpad-isa', 'GPU:');
}

function readSensorValue(sensorOutput, blockName, label) {
    let inBlock = false;

    for (const line of sensorOutput.split('\n')) {
        if (line.trim() === '') {
            inBlock = false;
            continue;
        }

        if (!inBlock) {
            inBlock = line.includes(blockName);
            continue;
        }

        if (!line.includes(label))
            continue;

        return parseTemperature(line);
    }

    return null;
}

function parseTemperature(line) {
    const match = line.match(/[+-]?(\d+(?:\.\d+)?)\s*°C/);
    if (match === null)
        return null;

    return Math.round(Number.parseFloat(match[1]));
}

function parseNvidiaStats(output) {
    const line = output.trim().split('\n')[0];
    if (line === '')
        return null;

    const fields = line.split(',').map(field => field.trim());
    if (fields.length < 2)
        return null;

    const usage = Number.parseInt(fields[0], 10);
    const temp = Number.parseInt(fields[1], 10);
    if (Number.isNaN(usage) || Number.isNaN(temp))
        return null;

    return {
        usage: clampPercent(usage),
        temp,
    };
}

function formatPercent(value) {
    if (value === null)
        return ' --%';

    return `${clampPercent(value).toString().padStart(3, ' ')}%`;
}

function formatTemp(value) {
    if (value === null)
        return ' --°';

    return `${Math.max(0, Math.min(value, 999)).toString().padStart(3, ' ')}°`;
}

function formatGhz(valueMhz) {
    if (valueMhz === null)
        return '-.-G';

    const ghz = Math.max(0, Math.min(valueMhz / 1000, 9.9));
    return `${ghz.toFixed(1)}G`;
}

function percentClass(value) {
    if (value === null)
        return 'syswatch-dim';

    if (value < 30)
        return 'syswatch-green';
    if (value < 60)
        return 'syswatch-yellow';
    if (value < 85)
        return 'syswatch-orange';
    return 'syswatch-red';
}

function tempClass(value) {
    if (value === null)
        return 'syswatch-dim';

    if (value < TEMP_WARN)
        return 'syswatch-green';
    if (value < TEMP_HOT)
        return 'syswatch-yellow';
    if (value < TEMP_CRIT)
        return 'syswatch-orange';
    return 'syswatch-red';
}

function freqClass(valueMhz) {
    if (valueMhz === null)
        return 'syswatch-dim';

    const percent = Math.round((valueMhz * 100) / CPU_MAX_MHZ_FALLBACK);
    return percentClass(percent);
}

function clampPercent(value) {
    return Math.max(0, Math.min(value, 100));
}
