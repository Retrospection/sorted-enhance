import SwiftUI

struct PlannerEmptyState: View {
    let section: PlannerSection

    @Environment(\.colorScheme) private var colorScheme

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.67, green: 0.71, blue: 0.75)
            : Color(red: 0.337, green: 0.373, blue: 0.412)
    }

    var body: some View {
        switch section {
        case .schedule, .inbox:
            ViewThatFits(in: .vertical) {
                artworkAndMessage
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .lists, .tags, .history, .trash:
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var artworkAndMessage: some View {
        VStack(spacing: 38) {
            Canvas { context, size in
                var context = context
                let scale = size.width / artworkSize.width
                context.scaleBy(x: scale, y: scale)
                context.drawLayer { layer in
                    let scene = EmptyLandscape(context: layer, color: ink)
                    if section == .inbox { scene.drawMountains() } else { scene.drawHills() }
                }
            }
            .aspectRatio(artworkSize, contentMode: .fit)
            .frame(maxWidth: artworkSize.width, maxHeight: artworkSize.height)
            .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var artworkSize: CGSize {
        section == .inbox ? CGSize(width: 195, height: 170) : CGSize(width: 176, height: 150)
    }

    private var message: LocalizedStringKey {
        switch section {
        case .schedule: "What a great day to get stuff done."
        case .inbox: "Sometimes one just needs to relax."
        case .lists: "No lists"
        case .tags: "No tags"
        case .history: "No history at the moment."
        case .trash: "Trash is empty"
        }
    }
}

private struct EmptyLandscape {
    let context: GraphicsContext
    let color: Color

    private func line(_ path: Path, width: CGFloat = 1.8) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    // Knock out the layer below each silhouette so the view's own background shows through.
    private func clear(_ silhouette: Path) {
        var cutout = context
        cutout.blendMode = .destinationOut
        cutout.fill(silhouette, with: .color(.black))
    }

    private func outline(_ path: Path) {
        clear(path)
        line(path)
    }

    private func contour(_ points: [CGPoint], width: CGFloat = 1.8) {
        line(Path { $0.addLines(points) }, width: width)
    }

    private func cloud(x: CGFloat, y: CGFloat, mirrored: Bool = false) {
        let path = Path { p in
            p.move(to: .init(x: 8, y: 25))
            p.addQuadCurve(to: .init(x: 2, y: 20), control: .init(x: 2, y: 25))
            p.addQuadCurve(to: .init(x: 8, y: 15), control: .init(x: 2, y: 15))
            p.addLine(to: .init(x: 19, y: 15))
            p.addQuadCurve(to: .init(x: 21, y: 12), control: .init(x: 22, y: 15))
            p.addQuadCurve(to: .init(x: 27, y: 4), control: .init(x: 18, y: 4))
            p.addLine(to: .init(x: 44, y: 4))
            p.addQuadCurve(to: .init(x: 50, y: 10), control: .init(x: 50, y: 4))
            p.addQuadCurve(to: .init(x: 54, y: 13), control: .init(x: 50, y: 13))
            p.addLine(to: .init(x: 67, y: 13))
            p.addQuadCurve(to: .init(x: 73, y: 19), control: .init(x: 73, y: 13))
            p.addQuadCurve(to: .init(x: 67, y: 25), control: .init(x: 73, y: 25))
            p.addLine(to: .init(x: 55, y: 25))
            p.addQuadCurve(to: .init(x: 51, y: 29), control: .init(x: 51, y: 25))
            p.addQuadCurve(to: .init(x: 46, y: 32), control: .init(x: 50, y: 32))
            p.addLine(to: .init(x: 28, y: 32))
            p.addQuadCurve(to: .init(x: 22, y: 27), control: .init(x: 23, y: 32))
            p.addQuadCurve(to: .init(x: 19, y: 25), control: .init(x: 22, y: 25))
            p.closeSubpath()
        }
        let transform = CGAffineTransform(translationX: x + (mirrored ? 38 : -38), y: y - 18)
            .scaledBy(x: mirrored ? -1 : 1, y: 1)
        outline(path.applying(transform))
    }

    private func hill(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint) {
        let ridge = Path { p in
            p.move(to: start)
            p.addCurve(to: end, control1: control1, control2: control2)
        }
        var silhouette = ridge
        silhouette.addLine(to: .init(x: end.x, y: 155))
        silhouette.addLine(to: .init(x: start.x, y: 155))
        silhouette.closeSubpath()
        clear(silhouette)
        line(ridge)
    }

    private func stripedTree(x: CGFloat, y: CGFloat, radius: CGFloat, base: CGFloat) {
        let r = radius
        contour([.init(x: x, y: y + r * 0.5), .init(x: x, y: base)])
        let crown = Path(ellipseIn: CGRect(x: x-r, y: y-r, width: 2*r, height: 2*r))
        outline(crown)
        var clipped = context
        clipped.clip(to: crown)
        let bands = Path { p in
            for offset: CGFloat in [-0.85, -0.42, 0.02, 0.46, 0.9] {
                p.move(to: .init(x: x + r, y: y - r * 1.3 + offset * r))
                p.addQuadCurve(to: .init(x: x - r * 1.3, y: y + r * 0.8 + offset * r),
                               control: .init(x: x + r * 0.9, y: y + r * 0.5 + offset * r))
            }
        }
        clipped.stroke(bands, with: .color(color), lineWidth: 1.35)
    }

    private func squareTree(x: CGFloat, y: CGFloat, width: CGFloat, base: CGFloat) {
        let height = width * 1.14
        outline(Path(roundedRect: CGRect(x: x-width/2, y: y-height/2, width: width, height: height),
                     cornerRadius: width * 0.27))
        contour([.init(x: x, y: y - height * 0.22), .init(x: x, y: base)])
        contour([.init(x: x-width*0.28, y: y-height*0.16), .init(x: x, y: y+height*0.13),
                 .init(x: x+width*0.28, y: y-height*0.14)])
    }

    private func pine(x: CGFloat, y: CGFloat, height: CGFloat, base: CGFloat) {
        let h = height
        let w = h * 0.32
        contour([.init(x: x, y: y), .init(x: x, y: base)])
        let canopy = Path { p in
            p.move(to: .init(x: x, y: y-h*0.5))
            p.addQuadCurve(to: .init(x: x-w, y: y+h*0.4), control: .init(x: x-w*0.53, y: y-h*0.02))
            p.addQuadCurve(to: .init(x: x+w, y: y+h*0.4), control: .init(x: x, y: y+h*0.56))
            p.addQuadCurve(to: .init(x: x, y: y-h*0.5), control: .init(x: x+w*0.42, y: y-h*0.06))
            p.closeSubpath()
        }
        outline(canopy)
        contour([.init(x: x, y: y-h*0.23), .init(x: x, y: y+h*0.46)], width: 1.4)
        for (level, span): (CGFloat, CGFloat) in [(0.05,0.28), (0.25,0.56)] {
            contour([.init(x: x-w*span, y: y+h*(level-0.10)), .init(x: x, y: y+h*level),
                     .init(x: x+w*span, y: y+h*(level-0.10))], width: 1.35)
        }
    }

    func drawHills() {
        cloud(x: 44, y: 16)
        cloud(x: 129, y: 36, mirrored: true)
        hill(from: .init(x: 2, y: 97), control1: .init(x: 35, y: 72),
             control2: .init(x: 84, y: 61), to: .init(x: 139, y: 104))
        squareTree(x: 33, y: 66, width: 18, base: 80)
        stripedTree(x: 71, y: 53, radius: 12, base: 75)
        hill(from: .init(x: 51, y: 101), control1: .init(x: 89, y: 73),
             control2: .init(x: 125, y: 81), to: .init(x: 172, y: 137))
        pine(x: 116, y: 69, height: 31, base: 90)
        hill(from: .init(x: 1, y: 126), control1: .init(x: 39, y: 88),
             control2: .init(x: 98, y: 90), to: .init(x: 172, y: 137))
        stripedTree(x: 15, y: 103, radius: 9, base: 114)
        pine(x: 137, y: 100, height: 26, base: 118)
        hill(from: .init(x: 28, y: 142), control1: .init(x: 77, y: 110),
             control2: .init(x: 135, y: 107), to: .init(x: 173, y: 137))
        squareTree(x: 58, y: 115, width: 18, base: 128)
        stripedTree(x: 113, y: 119, radius: 11, base: 136)
        pine(x: 165, y: 122, height: 18, base: 134)
        let foreground = Path { p in
            p.move(to: .init(x: 79, y: 148))
            p.addQuadCurve(to: .init(x: 173, y: 137), control: .init(x: 121, y: 122))
        }
        line(foreground)
    }

    private func mountain(foot: CGPoint, peak: CGPoint, end: CGPoint) {
        let top = Path { p in
            p.move(to: foot)
            p.addLine(to: .init(x: peak.x-1, y: peak.y+1))
            p.addQuadCurve(to: .init(x: peak.x+1, y: peak.y+1), control: peak)
            p.addLine(to: end)
        }
        var mass = top
        mass.closeSubpath()
        clear(mass)
        line(top)
        let height = min(foot.y, end.y) - peak.y
        let level = peak.y + height * 0.32
        let x1 = peak.x + (foot.x - peak.x) * (level-peak.y) / (foot.y-peak.y)
        let x2 = peak.x + (end.x - peak.x) * (level-peak.y) / (end.y-peak.y)
        let width = x2-x1
        contour([.init(x: x1, y: level), .init(x: x1+width*0.23, y: level-2.7),
                 .init(x: x1+width*0.40, y: level+3), .init(x: x1+width*0.65, y: level-2.2),
                 .init(x: x1+width*0.82, y: level+1.8), .init(x: x2, y: level)])
    }

    func drawMountains() {
        mountain(foot: .init(x: 7, y: 95), peak: .init(x: 43, y: 37), end: .init(x: 87, y: 97))
        mountain(foot: .init(x: 58, y: 96), peak: .init(x: 112, y: 10), end: .init(x: 167, y: 96))
        mountain(foot: .init(x: 111, y: 95), peak: .init(x: 150, y: 39), end: .init(x: 192, y: 95))
        mountain(foot: .init(x: 25, y: 97), peak: .init(x: 63, y: 53), end: .init(x: 105, y: 97))
        mountain(foot: .init(x: 113, y: 94), peak: .init(x: 137, y: 63), end: .init(x: 166, y: 96))

        hill(from: .init(x: 3, y: 100), control1: .init(x: 30, y: 87),
             control2: .init(x: 63, y: 88), to: .init(x: 92, y: 97))
        hill(from: .init(x: 99, y: 97), control1: .init(x: 128, y: 90),
             control2: .init(x: 163, y: 86), to: .init(x: 192, y: 98))
        let banks = Path { p in
            p.move(to: .init(x: 92, y: 97))
            p.addQuadCurve(to: .init(x: 96, y: 106), control: .init(x: 113, y: 102))
            p.addQuadCurve(to: .init(x: 105, y: 124), control: .init(x: 62, y: 118))
            p.addQuadCurve(to: .init(x: 88, y: 144), control: .init(x: 139, y: 130))
            p.addQuadCurve(to: .init(x: 68, y: 163), control: .init(x: 64, y: 151))
            p.move(to: .init(x: 99, y: 97))
            p.addQuadCurve(to: .init(x: 107, y: 109), control: .init(x: 123, y: 100))
            p.addQuadCurve(to: .init(x: 117, y: 121), control: .init(x: 82, y: 118))
            p.addQuadCurve(to: .init(x: 125, y: 148), control: .init(x: 166, y: 126))
            p.addQuadCurve(to: .init(x: 115, y: 166), control: .init(x: 106, y: 158))
            p.move(to: .init(x: 5, y: 123))
            p.addQuadCurve(to: .init(x: 73, y: 124), control: .init(x: 35, y: 112))
            p.move(to: .init(x: 143, y: 120))
            p.addQuadCurve(to: .init(x: 189, y: 126), control: .init(x: 167, y: 115))
            p.move(to: .init(x: 22, y: 142))
            p.addQuadCurve(to: .init(x: 61, y: 143), control: .init(x: 42, y: 137))
        }
        line(banks)
        pine(x: 58, y: 83, height: 21, base: 92)
        pine(x: 148, y: 81, height: 20, base: 93)
        stripedTree(x: 28, y: 101, radius: 10, base: 118)
        squareTree(x: 52, y: 125, width: 15, base: 139)
        pine(x: 162, y: 103, height: 27, base: 120)
        pine(x: 177, y: 113, height: 18, base: 123)
    }
}
