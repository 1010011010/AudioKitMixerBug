import SwiftUI

struct ContentView: View {
    var body: some View {
		NavigationView {
			List {
				NavigationLink(destination: LooperView()) {
					Label("LooperView", systemImage: "")
				}
			}
			.navigationTitle("Menu")
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
