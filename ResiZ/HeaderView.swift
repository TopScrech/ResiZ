import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.tint, in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text("ResiZ")
                    .font(.headline)

                Text("Press \(Text("⌃⌘F").monospaced().bold()) to toggle fullscreen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Press Control Command F to toggle fullscreen")
            }

            Spacer()
        }
    }
}
