import SwiftUI

struct ContentView: View {
	@State private var vaultPath = "/Users/enw/Documents/Areas/vault"
	@State private var notes: [Note] = []
	@State private var selectedNote: Note?
	@State private var isLoading = false
	@State private var searchText = ""
	
	var filteredNotes: [Note] {
		if searchText.isEmpty {
			return notes
		}
		return notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
	}
	
	var body: some View {
		HSplitView {
			// Vault navigator sidebar
			vaultSidebar
			
			// Main content area
			VSplitView {
				// Note list
				NoteListView(
					notes: filteredNotes,
					selectedNote: $selectedNote,
					searchText: $searchText
				)
				
				// Note detail
				if let note = selectedNote {
					NoteDetailView(note: note)
						.splitViewDividerStyle(.thick)
				} else {
					PlaceholderView()
						.splitViewDividerStyle(.thick)
				}
			}
		}
		.task {
			await loadNotes()
		}
		.frame(minWidth: 1200, minHeight: 700)
		.padding(8)
		.background(Color.black)
		.foregroundColor(.white)
		.font(.system(size: 12, weight: .regular, design: .monospaced))
	}
	
	@MainActor
	private func loadNotes() async {
		isLoading = true
		defer { isLoading = false }
		
		guard FileManager.default.fileExists(atPath: vaultPath) else {
			return
		}
		
		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: URL(fileURLWithPath: vaultPath),
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			)
			
			let mdFiles = contents.filter { $0.pathExtension == "md" }
			
			notes = try await withThrowingTaskGroup(of: Note.self) { group in
				for url in mdFiles {
					group.addTask {
						let content = try String(contentsOf: url, encoding: .utf8)
						let title = url.lastPathComponent
							.replacingOccurrences(of: ".md", with: "")
						return Note(id: url.lastPathComponent, title: title, content: content, path: url.path)
					}
				}
				return await group.results().compactMap { try? $0 }
			}
		} catch {
			print("Error loading vault: \(error)")
		}
	}
	
	private var vaultSidebar: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("VAULT: \(vaultPath)")
				.font(.system(size: 10, weight: .semibold))
				.padding(8)
				.background(Color.gray.opacity(0.2))
			
			List(filteredNotes, selection: $selectedNote) { note in
				Text("\(note.title)")
					.font(.system(size: 11))
					.padding(.vertical, 2)
					.padding(.horizontal, 8)
					.background(note == selectedNote ? Color.gray.opacity(0.3) : Color.clear)
					.onTapGesture {
						selectedNote = note
					}
			}
			.listStyle(.plain)
			.frame(width: 250)
		}
	}
}

struct NoteListView: View {
	let notes: [Note]
	@Binding var selectedNote: Note?
	@Binding var searchText: String
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack {
				Text("NOTES")
					.font(.system(size: 10, weight: .semibold))
				Spacer()
			TextField("search...", text: $searchText)
					.font(.system(size: 11))
					.background(Color.gray.opacity(0.1))
					.padding(4)
					.cornerRadius(2)
			}
			.padding(8)
			.background(Color.gray.opacity(0.2))
			
			List(notes, selection: $selectedNote) { note in
				Text("\(note.title)")
					.font(.system(size: 11))
					.padding(.vertical, 2)
					.padding(.horizontal, 8)
					.background(note == selectedNote ? Color.gray.opacity(0.3) : Color.clear)
					.onTapGesture {
						selectedNote = note
					}
			}
			.listStyle(.plain)
		}
	}
}

struct NoteDetailView: View {
	let note: Note
	
	var body: some View {
		TextEditor(text: .constant(note.content))
			.font(.system(size: 12, weight: .regular, design: .monospaced))
			.padding(8)
			.background(Color.black)
			.foregroundColor(.white)
	}
}

struct PlaceholderView: View {
	var body: some View {
		VStack {
			Text("SELECT A NOTE")
				.font(.system(size: 14, weight: .semibold))
				.foregroundColor(.gray)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black)
	}
}

struct Note: Identifiable, Hashable {
	let id: String
	let title: String
	let content: String
	let path: String
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	static func == (lhs: Note, rhs: Note) -> Bool {
		lhs.id == rhs.id
	}
}

#Preview {
	ContentView()
}
