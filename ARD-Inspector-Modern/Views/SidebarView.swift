import SwiftUI
import Observation

struct ResolvedARDItem: Identifiable, Hashable {
    let id: String
    let name: String
    let children: [ResolvedARDItem]?
    let computer: ARDComputer?
}

struct SidebarView: View {
    @Bindable var viewModel: ARDViewModel
    
    var body: some View {
        Text("ARD Lists")
            .font(Font.headline.weight(.bold))
        List(selection: $viewModel.selectedId) {
            ForEach(resolvedItems, id: \.id) { item in
                SidebarItemView(item: item, viewModel: viewModel)
            }
        }
        .navigationTitle("ARD Inspector")
        .listStyle(.sidebar)
    }
    
    var resolvedItems: [ResolvedARDItem] {
        viewModel.items.map { resolve($0) }
    }
    
    func resolve(_ item: ARDItem) -> ResolvedARDItem {
        switch item {
        case .computer(let c):
            return ResolvedARDItem(id: c.id, name: c.name, children: nil, computer: c)
        case .list(let l):
            let children = l.members.compactMap { uuid in
                if let computer = viewModel.computers[uuid] {
                    return ResolvedARDItem(id: computer.id, name: computer.name, children: nil, computer: computer)
                }
                return nil
            }
            return ResolvedARDItem(id: l.id, name: l.name, children: children, computer: nil)
        case .folder(let f):
            let children = f.members.compactMap { uuid in
                if let list = findList(id: uuid) {
                    return resolve(.list(list))
                } else if let folder = findFolder(id: uuid) {
                    return resolve(.folder(folder))
                } else if let computer = viewModel.computers[uuid] {
                    return ResolvedARDItem(id: computer.id, name: computer.name, children: nil, computer: computer)
                }
                return nil
            }
            return ResolvedARDItem(id: f.id, name: f.name, children: children, computer: nil)
        }
    }
    
    private func findList(id: String) -> ARDList? {
        for item in viewModel.items {
            if case .list(let l) = item, l.id == id {
                return l
            }
        }
        return nil
    }
    
    private func findFolder(id: String) -> ARDFolder? {
        for item in viewModel.items {
            if case .folder(let f) = item, f.id == id {
                return f
            }
        }
        return nil
    }
}

struct SidebarItemView: View {
    let item: ResolvedARDItem
    var viewModel: ARDViewModel
    
    var body: some View {
        if let children = item.children {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { viewModel.expandedItems.contains(item.id) },
                    set: { expanded in
                        if expanded {
                            viewModel.expandedItems.insert(item.id)
                        } else {
                            viewModel.expandedItems.remove(item.id)
                        }
                    }
                ),
                content: {
                    ForEach(children) { child in
                        SidebarItemView(item: child, viewModel: viewModel)
                    }
                },
                label: {
                    Label(item.name, systemImage: item.icon)
                        .tag(item.id)
                        .onTapGesture {
                            if viewModel.expandedItems.contains(item.id) {
                                viewModel.expandedItems.remove(item.id)
                            } else {
                                viewModel.expandedItems.insert(item.id)
                            }
                        }
                }
            )
        } else {
            Label(item.name, systemImage: item.icon)
                .tag(item.id)
        }
    }
}

extension ResolvedARDItem {
    var icon: String {
        if children == nil && computer != nil {
            return "desktopcomputer"
        } else if children != nil {
            return "folder"
        }
        return "list.bullet"
    }
}
