import SwiftUI
import MacroAPI
import AppKit

@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config
    @State private var isExpanded = false
    @State private var hoveredMenuIndex: Int? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            LiquidGlassBackground(
                variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                cornerRadius: config.widgetCornerRadius
            ) {
                Text(model.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: config.activeAppWidth)
                    .frame(height: config.widgetHeight)
            }
            .contentShape(Rectangle())
            .onHover { hover in
                withAnimation(.none) {
                    isExpanded = hover || hoveredMenuIndex != nil
                }
            }
            
            if isExpanded {
                ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                    MenuButton(
                        item: item,
                        config: config,
                        onHoverChange: { hover in
                            withAnimation(.none) {
                                if hover {
                                    hoveredMenuIndex = index
                                    isExpanded = true
                                } else {
                                    hoveredMenuIndex = nil
                                }
                            }
                        }
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hover in
            if !hover {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if hoveredMenuIndex == nil {
                        withAnimation(.none) {
                            isExpanded = false
                        }
                    }
                }
            }
        }
    }
}

struct MenuButton: View {
    let item: MenuItemData
    let config: Config
    let onHoverChange: (Bool) -> Void
    @State private var showPopover = false
    
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Text(item.title)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: config.widgetHeight)
        }
        .contentShape(Rectangle())
        .onHover { hover in
            onHoverChange(hover)
            withAnimation(.none) {
                showPopover = hover
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            if let submenu = item.submenu {
                SubmenuView(items: submenu, config: config, showPopover: $showPopover, onHoverChange: onHoverChange)
            }
        }
    }
}

struct SubmenuView: View {
    let items: [MenuItemData]
    let config: Config
    @Binding var showPopover: Bool
    let onHoverChange: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                if item.isSeparator {
                    Divider().padding(.vertical, 4)
                } else {
                    Button(action: {
                        if let action = item.action {
                            NSApp.sendAction(action, to: nil, from: nil)
                        }
                        showPopover = false
                    }) {
                        HStack {
                            Text(item.title)
                                .foregroundColor(item.isEnabled ? .white : .gray)
                                .font(.system(size: 12))
                            Spacer()
                            if !item.keyEquivalent.isEmpty {
                                Text(item.keyEquivalent)
                                    .foregroundColor(.gray)
                                    .font(.system(size: 11))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(minWidth: 180)
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .background(Color.white.opacity(0.1))
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .onHover { hover in
            onHoverChange(hover)
        }
    }
}