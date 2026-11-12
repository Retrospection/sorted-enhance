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
                if section == .inbox {
                    EmptyLandscape.drawMountains(in: context, color: ink)
                } else {
                    EmptyLandscape.drawHills(in: context, color: ink)
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

private enum EmptyLandscape {
    static func drawHills(in context: GraphicsContext, color: Color) {
        let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        let ink = GraphicsContext.Shading.color(color)

        func outline(_ path: Path) {
            context.stroke(path, with: ink, style: stroke)
        }

        func cloud(at origin: CGPoint, scale: CGFloat) {
            let shape = Path { path in
                path.move(to: CGPoint(x: 5, y: 18))
                path.addQuadCurve(to: CGPoint(x: 1, y: 14), control: CGPoint(x: 1, y: 18))
                path.addQuadCurve(to: CGPoint(x: 5, y: 10), control: CGPoint(x: 1, y: 10))
                path.addLine(to: CGPoint(x: 11, y: 10))
                path.addLine(to: CGPoint(x: 11, y: 7))
                path.addQuadCurve(to: CGPoint(x: 15, y: 3), control: CGPoint(x: 11, y: 3))
                path.addLine(to: CGPoint(x: 23, y: 3))
                path.addQuadCurve(to: CGPoint(x: 27, y: 7), control: CGPoint(x: 27, y: 3))
                path.addLine(to: CGPoint(x: 27, y: 8))
                path.addLine(to: CGPoint(x: 34, y: 8))
                path.addQuadCurve(to: CGPoint(x: 38, y: 12), control: CGPoint(x: 38, y: 8))
                path.addLine(to: CGPoint(x: 41, y: 12))
                path.addQuadCurve(to: CGPoint(x: 44, y: 15), control: CGPoint(x: 44, y: 12))
                path.addQuadCurve(to: CGPoint(x: 41, y: 18), control: CGPoint(x: 44, y: 18))
                path.closeSubpath()
            }
            let transform = CGAffineTransform(translationX: origin.x, y: origin.y)
                .scaledBy(x: scale, y: scale)
            outline(shape.applying(transform))
        }

        cloud(at: CGPoint(x: 19, y: 17), scale: 0.88)
        cloud(at: CGPoint(x: 92, y: 4), scale: 1.12)

        let ground = Path { path in
            path.move(to: CGPoint(x: 5, y: 106))
            path.addQuadCurve(to: CGPoint(x: 80, y: 99), control: CGPoint(x: 47, y: 82))
            path.move(to: CGPoint(x: 60, y: 109))
            path.addQuadCurve(to: CGPoint(x: 169, y: 102), control: CGPoint(x: 120, y: 76))
            path.move(to: CGPoint(x: 10, y: 118))
            path.addQuadCurve(to: CGPoint(x: 114, y: 114), control: CGPoint(x: 62, y: 99))
            path.move(to: CGPoint(x: 45, y: 131))
            path.addQuadCurve(to: CGPoint(x: 160, y: 116), control: CGPoint(x: 100, y: 100))
            path.move(to: CGPoint(x: 71, y: 138))
            path.addQuadCurve(to: CGPoint(x: 143, y: 124), control: CGPoint(x: 102, y: 119))
        }
        outline(ground)

        let crown = CGRect(x: 22, y: 60, width: 19, height: 26)
        outline(Path(ellipseIn: crown))
        var stripes = context
        stripes.clip(to: Path(ellipseIn: crown))
        let hatching = Path { path in
            for x in stride(from: 14, through: 44, by: 4) {
                path.move(to: CGPoint(x: x, y: 85))
                path.addLine(to: CGPoint(x: x + 11, y: 58))
            }
        }
        stripes.stroke(hatching, with: ink, style: StrokeStyle(lineWidth: 1.3))
        outline(Path { path in
            path.move(to: CGPoint(x: 31.5, y: 86))
            path.addLine(to: CGPoint(x: 31.5, y: 95.5))
        })

        outline(Path(roundedRect: CGRect(x: 69, y: 53, width: 25, height: 33), cornerRadius: 8))
        outline(Path { path in
            path.move(to: CGPoint(x: 81, y: 67))
            path.addLine(to: CGPoint(x: 81, y: 98))
            path.move(to: CGPoint(x: 75, y: 72))
            path.addLine(to: CGPoint(x: 81, y: 79))
            path.addLine(to: CGPoint(x: 88, y: 70))
        })

        outline(Path { path in
            path.addLines([
                CGPoint(x: 145, y: 57),
                CGPoint(x: 138, y: 70), CGPoint(x: 142, y: 70),
                CGPoint(x: 135, y: 82), CGPoint(x: 155, y: 82),
                CGPoint(x: 148, y: 70), CGPoint(x: 152, y: 70),
                CGPoint(x: 145, y: 57)
            ])
            path.move(to: CGPoint(x: 145, y: 82))
            path.addLine(to: CGPoint(x: 145, y: 94.5))
        })
    }

    static func drawMountains(in context: GraphicsContext, color: Color) {
        let ink = GraphicsContext.Shading.color(color)
        let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)

        func contour(_ points: [CGPoint]) {
            context.stroke(Path { $0.addLines(points) }, with: ink, style: stroke)
        }

        let peak = Path { path in
            path.move(to: CGPoint(x: 5, y: 95))
            path.addLine(to: CGPoint(x: 44, y: 42))
            path.addQuadCurve(to: CGPoint(x: 48, y: 42), control: CGPoint(x: 46, y: 39))
            path.addLine(to: CGPoint(x: 72, y: 72))
            path.move(to: CGPoint(x: 56, y: 92))
            path.addLine(to: CGPoint(x: 106, y: 14))
            path.addQuadCurve(to: CGPoint(x: 110, y: 14), control: CGPoint(x: 108, y: 11))
            path.addLine(to: CGPoint(x: 139, y: 59))
            path.move(to: CGPoint(x: 125, y: 80))
            path.addLine(to: CGPoint(x: 153, y: 36))
            path.addQuadCurve(to: CGPoint(x: 157, y: 36), control: CGPoint(x: 155, y: 33))
            path.addLine(to: CGPoint(x: 191, y: 90))
        }
        context.stroke(peak, with: ink, style: stroke)
        contour([.init(x: 33, y: 57), .init(x: 42, y: 53), .init(x: 48, y: 60),
                 .init(x: 53, y: 55), .init(x: 61, y: 58)])
        contour([.init(x: 89, y: 41), .init(x: 98, y: 37), .init(x: 102, y: 43),
                 .init(x: 110, y: 35), .init(x: 118, y: 43), .init(x: 123, y: 36)])
        contour([.init(x: 144, y: 50), .init(x: 151, y: 47), .init(x: 157, y: 54),
                 .init(x: 162, y: 49), .init(x: 167, y: 52)])

        let banks = Path { path in
            path.move(to: .init(x: 4, y: 101))
            path.addQuadCurve(to: .init(x: 30.5, y: 93.5), control: .init(x: 18, y: 96))
            path.move(to: .init(x: 45.5, y: 92.7))
            path.addQuadCurve(to: .init(x: 90, y: 97), control: .init(x: 66, y: 90))
            path.move(to: .init(x: 102, y: 97))
            path.addQuadCurve(to: .init(x: 190, y: 96), control: .init(x: 153, y: 80))
            path.move(to: .init(x: 79, y: 164))
            path.addQuadCurve(to: .init(x: 101, y: 136), control: .init(x: 134, y: 146))
            path.addQuadCurve(to: .init(x: 103, y: 112), control: .init(x: 68, y: 127))
            path.addQuadCurve(to: .init(x: 91, y: 97), control: .init(x: 131, y: 101))
            path.move(to: .init(x: 132, y: 154))
            path.addQuadCurve(to: .init(x: 118, y: 131), control: .init(x: 158, y: 139))
            path.addQuadCurve(to: .init(x: 117, y: 114), control: .init(x: 91, y: 125))
            path.addQuadCurve(to: .init(x: 102, y: 97), control: .init(x: 141, y: 98))
            path.move(to: .init(x: 16, y: 128))
            path.addQuadCurve(to: .init(x: 68, y: 126), control: .init(x: 44, y: 120))
            path.move(to: .init(x: 140, y: 124))
            path.addQuadCurve(to: .init(x: 181, y: 127), control: .init(x: 164, y: 120))
        }
        context.stroke(banks, with: ink, style: stroke)
        context.stroke(Path(ellipseIn: CGRect(x: 30, y: 89, width: 16, height: 21)), with: ink, style: stroke)
        contour([.init(x: 38, y: 100), .init(x: 38, y: 122)])
        contour([.init(x: 34, y: 101), .init(x: 38, y: 105), .init(x: 43, y: 99)])
        contour([.init(x: 151, y: 94), .init(x: 144, y: 106), .init(x: 148, y: 106),
                 .init(x: 140, y: 118), .init(x: 162, y: 118), .init(x: 154, y: 106),
                 .init(x: 158, y: 106), .init(x: 151, y: 94)])
        contour([.init(x: 151, y: 118), .init(x: 151, y: 123)])
    }
}
