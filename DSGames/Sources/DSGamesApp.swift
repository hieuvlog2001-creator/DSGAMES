import SwiftUI
import UIKit

@main
struct DSGamesApp: App {
    @StateObject private var model = GameStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct GameItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let image: String
    let accent: Color
}

final class GameStore: ObservableObject {
    @Published var selectedTab = 0
    @Published var search = ""
    @Published var installed: Set<String> = []
    let games: [GameItem] = [
        .init(title: "Arena of Valor", subtitle: "Liên Quân Mobile", image: "aov", accent: .cyan),
        .init(title: "CrossFire Mobile", subtitle: "CrossFire Legends", image: "cfm", accent: .red),
        .init(title: "Free Fire MAX", subtitle: "Garena", image: "ffmax", accent: .orange),
        .init(title: "Wild Rift", subtitle: "League of Legends", image: "h_ahri", accent: .purple)
    ]
    var filtered: [GameItem] {
        guard !search.isEmpty else { return games }
        return games.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.subtitle.localizedCaseInsensitiveContains(search) }
    }
    func toggle(_ game: GameItem) { if installed.contains(game.title) { installed.remove(game.title) } else { installed.insert(game.title) } }
}

struct RootView: View {
    @EnvironmentObject var model: GameStore
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderView()
                Group {
                    switch model.selectedTab {
                    case 1: LibraryView()
                    case 2: ToolsView()
                    case 3: SettingsView()
                    default: HomeView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                BottomBar()
            }
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject var model: GameStore
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DSGames").font(.system(size: 25, weight: .bold, design: .rounded))
                Text("GAME CENTER").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "bell.fill").font(.system(size: 15, weight: .semibold)).frame(width: 38,height:38).background(.white.opacity(0.07)).clipShape(Circle())
                Text("T").font(.system(size: 16, weight: .bold)).frame(width: 38,height:38).background(.white.opacity(0.10)).clipShape(Circle())
            }
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
    }
}

struct HomeView: View {
    @EnvironmentObject var model: GameStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SearchBar()
                Text("Featured").font(.system(size: 21, weight: .bold)).padding(.horizontal, 18)
                FeaturedCard(game: model.games[0])
                Text("Games").font(.system(size: 21, weight: .bold)).padding(.horizontal, 18)
                LazyVStack(spacing: 10) { ForEach(model.filtered) { GameRow(game: $0) } }.padding(.horizontal, 18)
                Text("Champion library").font(.system(size: 21, weight: .bold)).padding(.horizontal, 18).padding(.top, 4)
                ChampionGrid().padding(.horizontal, 18)
                Spacer(minLength: 24)
            }.padding(.bottom, 12)
        }
    }
}

struct SearchBar: View {
    @EnvironmentObject var model: GameStore
    var body: some View {
        HStack(spacing: 10) { Image(systemName: "magnifyingglass"); TextField("Search games", text: $model.search).textInputAutocapitalization(.never) }
            .padding(.horizontal, 14).frame(height: 44).background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 18)
    }
}

struct FeaturedCard: View {
    @EnvironmentObject var model: GameStore
    let game: GameItem
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let ui = UIImage(named: game.image) { Image(uiImage: ui).resizable().scaledToFill().opacity(0.55).frame(maxWidth:.infinity,maxHeight:.infinity).clipped() }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius:24))
            VStack(alignment:.leading, spacing:8) {
                Text("RECOMMENDED").font(.system(size:10,weight:.bold)).tracking(1.5).foregroundStyle(game.accent)
                Text(game.title).font(.system(size:25,weight:.bold))
                Text(game.subtitle).font(.system(size:13)).foregroundStyle(.secondary)
                Button { model.toggle(game) } label: { Text(model.installed.contains(game.title) ? "Added" : "Add to library").font(.system(size:13,weight:.semibold)).padding(.horizontal,16).frame(height:36).background(.white).foregroundStyle(.black).clipShape(Capsule()) }
            }.padding(20)
        }.frame(height: 210).clipShape(RoundedRectangle(cornerRadius:24)).padding(.horizontal,18)
    }
}

struct GameRow: View {
    @EnvironmentObject var model: GameStore
    let game: GameItem
    var body: some View {
        HStack(spacing:13) {
            Group { if let ui=UIImage(named:game.image) { Image(uiImage:ui).resizable().scaledToFill() } else { Color.gray } }.frame(width:58,height:58).clipShape(RoundedRectangle(cornerRadius:14))
            VStack(alignment:.leading,spacing:4){ Text(game.title).font(.system(size:15,weight:.semibold)); Text(game.subtitle).font(.system(size:12)).foregroundStyle(.secondary) }
            Spacer()
            Button { model.toggle(game) } label: { Image(systemName:model.installed.contains(game.title) ? "checkmark" : "plus").font(.system(size:14,weight:.bold)).frame(width:34,height:34).background(.white.opacity(.08)).clipShape(Circle()) }
        }.padding(10).background(.white.opacity(.045)).clipShape(RoundedRectangle(cornerRadius:18))
    }
}

struct ChampionGrid: View {
    let names = ["h_ahri","h_akali","h_ashe","h_kassadin","h_jinx","h_ekko","h_yasuo","h_lux","h_garen","h_zed","h_jax","h_sylas"]
    var body: some View { LazyVGrid(columns:[GridItem(.adaptive(minimum:62),spacing:10)],spacing:10) { ForEach(names,id:\.self) { n in if let ui=UIImage(named:n) { Image(uiImage:ui).resizable().scaledToFill().frame(width:62,height:62).clipShape(RoundedRectangle(cornerRadius:14)) } } } }
}

struct LibraryView: View {
    @EnvironmentObject var model: GameStore
    var body: some View { ScrollView { VStack(alignment:.leading,spacing:16){ Text("My Library").font(.system(size:25,weight:.bold)).padding(.horizontal,18); if model.installed.isEmpty { EmptyState(icon:"square.stack.3d.up", text:"No games added yet") } else { ForEach(model.games.filter{model.installed.contains($0.title)}) { GameRow(game:$0) }.padding(.horizontal,18) } }.padding(.top,20) } }
}

struct ToolsView: View {
    let items=[("arrow.down.circle","Downloads","Manage downloaded resources"),("doc.text","Files","Browse local game files"),("rectangle.3.group","Services","App services and status"),("questionmark.circle","Help","About DSGames")]
    var body: some View { ScrollView { VStack(alignment:.leading,spacing:14){ Text("Tools").font(.system(size:25,weight:.bold)).padding(.horizontal,18); ForEach(items,id:\.0){ item in HStack(spacing:14){ Image(systemName:item.0).font(.system(size:19,weight:.semibold)).frame(width:42,height:42).background(.white.opacity(.07)).clipShape(RoundedRectangle(cornerRadius:12)); VStack(alignment:.leading){Text(item.1).font(.system(size:15,weight:.semibold));Text(item.2).font(.system(size:12)).foregroundStyle(.secondary)};Spacer();Image(systemName:"chevron.right").foregroundStyle(.secondary) }.padding(12).background(.white.opacity(.045)).clipShape(RoundedRectangle(cornerRadius:18)).padding(.horizontal,18)} }.padding(.top,20)} }
}

struct SettingsView: View {
    @AppStorage("haptics") var haptics=true
    @AppStorage("autoLaunch") var autoLaunch=false
    var body: some View { Form { Section("General"){Toggle("Haptics",isOn:$haptics);Toggle("Auto launch",isOn:$autoLaunch)} Section("About"){LabeledContent("Version","1.8");LabeledContent("Build","Rebuild");Text("DSGames is a game-library interface recreated from the supplied app package. Game-process injection, anti-debugging and exploit functionality are intentionally not included.").font(.footnote).foregroundStyle(.secondary)} }.scrollContentBackground(.hidden).background(Color.black).foregroundStyle(.white) }
}

struct EmptyState: View { let icon:String;let text:String;var body:some View{VStack(spacing:12){Image(systemName:icon).font(.system(size:42)).foregroundStyle(.secondary);Text(text).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(60)} }

struct BottomBar: View { @EnvironmentObject var model: GameStore; var body: some View { HStack { TabButton("house.fill","Home",0);TabButton("square.stack.3d.up.fill","Library",1);TabButton("wrench.and.screwdriver.fill","Tools",2);TabButton("gearshape.fill","Settings",3) }.padding(.horizontal,12).padding(.top,10).padding(.bottom,8).background(.black.opacity(.96)) }
    @ViewBuilder func TabButton(_ icon:String,_ title:String,_ tab:Int)->some View { Button { model.selectedTab=tab } label:{ VStack(spacing:4){Image(systemName:icon);Text(title).font(.system(size:10,weight:.medium))}.foregroundStyle(model.selectedTab==tab ? .white : .secondary).frame(maxWidth:.infinity) } }
}
