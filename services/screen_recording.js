.pragma library

// When the recording started, in epoch milliseconds, read out of the path the recorder is
// writing to. `capture-screenrecording` names the file from `date +'%Y-%m-%d_%H-%M-%S'` at
// the moment it launches gpu-screen-recorder, which makes the name the only record of the
// start time that survives a shell restart mid-recording -- the alternative, counting from
// when this shell first noticed the file, resets the clock every time the bar reloads.
//
// Returns null for anything that does not carry a full timestamp, so a renamed or
// hand-written state file shows no clock rather than a wild one.
function parseStartTime(path) {
    var match = /(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/.exec(String(path ?? ""));
    if (!match)
        return null;

    var year = Number(match[1]);
    var month = Number(match[2]);
    var day = Number(match[3]);
    var hour = Number(match[4]);
    var minute = Number(match[5]);
    var second = Number(match[6]);

    // Checked rather than handed straight to Date, which rolls a month of 13 into the next
    // year instead of rejecting it.
    if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59)
        return null;

    // The recorder stamps the name in local time, so this has to read it back as local too.
    var started = new Date(year, month - 1, day, hour, minute, second);
    if (started.getMonth() !== month - 1 || started.getDate() !== day)
        return null;

    return started.getTime();
}

function pad2(value) {
    return value < 10 ? `0${value}` : String(value);
}

// Elapsed seconds as a running clock. Minutes stay unpadded until there is an hour in
// front of them, so a short recording reads 0:07 rather than 00:07 and the common case
// stays as narrow as it can in the bar.
function formatElapsed(seconds) {
    var total = Math.floor(Number(seconds));
    if (!Number.isFinite(total) || total < 0)
        total = 0;

    var hours = Math.floor(total / 3600);
    var minutes = Math.floor(total / 60) % 60;
    var remainder = total % 60;

    if (hours > 0)
        return `${hours}:${pad2(minutes)}:${pad2(remainder)}`;
    return `${minutes}:${pad2(remainder)}`;
}
