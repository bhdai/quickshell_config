import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 button with expressive bounciness.
 * See https://m3.material.io/components/button-groups/overview
 */
Button {
    id: root
    property bool toggled
    property string buttonText
    property real buttonRadius: 8
    property real buttonRadiusPressed: 6
    property var downAction // When left clicking (down)
    property var releaseAction // When left clicking (release)
    property var altAction // When right clicking
    property var middleClickAction // When middle clicking
    property bool bounce: true
    property real baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    property real baseHeight: contentItem.implicitHeight + verticalPadding * 2
    property var parentGroup: root.parent
    property int indexInParent: {
        if (!parentGroup || !parentGroup.children)
            return 0;
        return parentGroup.children.indexOf(root);
    }
    property int clickIndex: parentGroup?.clickIndex ?? -1
    property int visibleChildCount: parentGroup?.visibleChildCount ?? 1

    // Position-aware expansion: buttons at edges expand less
    property bool isAtSide: indexInParent === 0 || indexInParent === (visibleChildCount - 1)
    property real clickedWidth: baseWidth + (isAtSide ? 10 : 20)
    property real clickedHeight: baseHeight

    // Width handed down by an enclosing ButtonGroup, which keeps the row width fixed and
    // shrinks only the pressed button's neighbours. -1 outside such a group, where the
    // button instead grows on its own and the surrounding layout absorbs it.
    readonly property real groupWidth: parentGroup?.buttonWidths?.[indexInParent] ?? -1
    readonly property bool inButtonGroup: groupWidth >= 0

    Layout.fillWidth: !inButtonGroup && (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    Layout.fillHeight: !inButtonGroup && (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    implicitWidth: inButtonGroup ? groupWidth : ((root.down && bounce) ? clickedWidth : baseWidth)
    implicitHeight: (root.down && bounce) ? clickedHeight : baseHeight

    property color colBackground: Appearance.colors.colLayer2
    property color colBackgroundHover: Appearance.colors.colLayer2Hover
    property color colBackgroundActive: Appearance.colors.colPrimary
    property color colBackgroundToggled: Appearance.colors.colPrimary
    property color colBackgroundToggledHover: ColorUtils.transparentize(colBackgroundToggled, 0.3)
    property color colBackgroundToggledActive: Appearance.colors.colPrimary

    property real radius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real leftRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real rightRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property color color: root.enabled ? (root.toggled ? (root.down ? colBackgroundToggledActive : root.hovered ? colBackgroundToggledHover : colBackgroundToggled) : (root.down ? colBackgroundActive : root.hovered ? colBackgroundHover : colBackground)) : colBackground

    onDownChanged: {
        if (parentGroup?.clickIndex === undefined)
            return;
        if (root.down)
            parentGroup.clickIndex = indexInParent;
        else if (parentGroup.clickIndex === indexInParent)
            parentGroup.clickIndex = -1;
    }

    Behavior on implicitWidth {
        // An enclosing ButtonGroup animates the whole row from one progress value and hands
        // down a finished width each frame. Interpolating again here would fight it, and the
        // independently rounded result would drift the row's right-hand side mid-press.
        enabled: !root.inButtonGroup
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }
    }

    Behavior on leftRadius {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }

    Behavior on rightRadius {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: event => {
            if (event.button === Qt.RightButton) {
                if (root.altAction)
                    root.altAction();
                return;
            }
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction)
                    root.middleClickAction();
                return;
            }
            root.down = true;
            if (root.downAction)
                root.downAction();
        }
        onReleased: event => {
            root.down = false;
            if (event.button != Qt.LeftButton)
                return;
            if (root.releaseAction)
                root.releaseAction();
        }
        onClicked: event => {
            if (event.button != Qt.LeftButton)
                return;
            root.click();
        }
        onCanceled: event => {
            root.down = false;
        }

        onPressAndHold: () => {
            if (root.altAction) {
                root.altAction();
                root.down = false;
                root.clicked = false;
            }
        }
    }

    background: Rectangle {
        id: buttonBackground
        topLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomLeftRadius: root.leftRadius
        bottomRightRadius: root.rightRadius
        implicitHeight: 50

        color: root.color
        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }

    contentItem: Text {
        text: root.buttonText
    }
}
