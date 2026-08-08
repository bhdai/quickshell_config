import QtQuick

Canvas {
    id: root

    property var line1: []
    property var line2: []
    property real maximum: 1
    property int historyLength: 24
    property real slideProgress: 1
    property bool smoothScroll: true
    property bool fillUnderLine: true
    property color line1Color: "transparent"
    property color line2Color: "transparent"
    property real line1FillAlpha: 0.18
    property real line2FillAlpha: 0.12
    property int paintCount: 0

    function points(values) {
        if (values.length < 2)
            return [];

        const step = width / (historyLength - 1);
        const progress = smoothScroll ? slideProgress : 1;
        const startX = width - (values.length - 1) * step - step * progress + step;
        return values.map((value, index) => Qt.point(
            startX + index * step,
            height - 3 - Math.max(0, Math.min(1, value / maximum)) * (height - 6)
        ));
    }

    function paintSeries(ctx, values, color, fillAlpha) {
        const path = points(values);
        if (path.length < 2)
            return;

        if (fillUnderLine) {
            ctx.beginPath();
            ctx.moveTo(path[0].x, path[0].y);
            for (let i = 1; i < path.length; i++)
                ctx.lineTo(path[i].x, path[i].y);
            ctx.lineTo(path[path.length - 1].x, height);
            ctx.lineTo(path[0].x, height);
            ctx.closePath();
            ctx.globalAlpha = fillAlpha;
            ctx.fillStyle = color;
            ctx.fill();
            ctx.globalAlpha = 1;
        }

        ctx.beginPath();
        ctx.moveTo(path[0].x, path[0].y);
        for (let i = 1; i < path.length; i++)
            ctx.lineTo(path[i].x, path[i].y);
        ctx.lineWidth = 2;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;
        ctx.stroke();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        paintSeries(ctx, line1, line1Color, line1FillAlpha);
        paintSeries(ctx, line2, line2Color, line2FillAlpha);
        paintCount++;
    }

    onLine1Changed: requestPaint()
    onLine2Changed: requestPaint()
    onMaximumChanged: requestPaint()
    onSlideProgressChanged: {
        if (smoothScroll)
            requestPaint();
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
