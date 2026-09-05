import QtQuick
import QtQuick.Shapes

// A filled rectangle with per-corner radii that behave like CSS border-radius:
// radii larger than the box are scaled down together, so a 10/24 pair on a
// 27 px bubble stays a 10/24 *shape* (8/19) instead of Qt Rectangle's
// clamp-to-half-height, which flattens the skew. The bar's whole look lives
// in this difference.
Item {
    id: root
    property color color: "white"
    property real topLeft: 0
    property real topRight: 0
    property real bottomRight: 0
    property real bottomLeft: 0

    readonly property real f: {
        const w = width, h = height
        if (w <= 0 || h <= 0) return 1
        const sums = [topLeft + topRight, bottomLeft + bottomRight, topLeft + bottomLeft, topRight + bottomRight]
        const lims = [w, w, h, h]
        let f = 1
        for (let i = 0; i < 4; i++) if (sums[i] > 0) f = Math.min(f, lims[i] / sums[i])
        return f
    }
    readonly property real tl: topLeft * f
    readonly property real tr: topRight * f
    readonly property real br: bottomRight * f
    readonly property real bl: bottomLeft * f

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            startX: root.tl; startY: 0
            PathLine { x: root.width - root.tr; y: 0 }
            PathArc { x: root.width; y: root.tr; radiusX: root.tr; radiusY: root.tr }
            PathLine { x: root.width; y: root.height - root.br }
            PathArc { x: root.width - root.br; y: root.height; radiusX: root.br; radiusY: root.br }
            PathLine { x: root.bl; y: root.height }
            PathArc { x: 0; y: root.height - root.bl; radiusX: root.bl; radiusY: root.bl }
            PathLine { x: 0; y: root.tl }
            PathArc { x: root.tl; y: 0; radiusX: root.tl; radiusY: root.tl }
        }
    }
}
