import SwiftUI

struct ServiceLogo: View {
    let url: URL?
    let name: String
    let categoryColor: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                    case .failure:
                        fallbackIcon
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        fallbackIcon
                    }
                }
                .frame(width: size, height: size)
            } else {
                fallbackIcon
            }
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(hex: categoryColor).opacity(0.15))

            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: categoryColor))
        }
        .frame(width: size, height: size)
    }
}
