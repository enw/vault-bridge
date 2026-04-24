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
		HSplitView(spacing: 0) {
			// Left sidebar - vault navigator
			vaultSidebar
			
			// Right panel - note content
			VSplitView(spacing: 0) {
				// Middle - note list
				NoteListView(
					notes: filteredNotes,
					selectedNote: $selectedNote,
					searchText: $searchText
				)
				
				// Bottom - note detail or placeholder
				if let note = selectedNote {
					NoteDetailView(note: note)
				} else {
					PlaceholderView()
				}
			}
		}
		.frame(minWidth: 1200, minHeight: 700)
		.padding(8)
		.background(Color.black)
		.foregroundColor(.white)
		.font(.system(size: 12, weight: .regular, design: .monospaced))
		.task {
			await loadNotes()
		}
	}
	
	@MainActor
	private func loadNotes() async {
		isLoading = true
		defer { isLoading = false }
		
		guard FileManager.default.fileExists(atPath: vaultPath) else {
			print("Vault path not found: \(vaultPath)")
			return
		}
		
		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: URL(fileURLWithPath: vaultPath),
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			)
			
			let mdFiles = contents.filter { $0.pathExtension == "md" }
			
			notes = try await withThrowingTaskGroup(of: Note.self, returning: [Note].self) { group in
				for url in mdFiles {
					group.addTask {
						let content = try String(contentsOf: url, encoding: .utf8)
						let title = url.lastPathComponent
							.replacingOccurrences(of: ".md", with: "")
						return Note(id: url.lastPathComponent, title: title, content: content, path: url.path)
					}
				}
				var results: [Note] = []
				while let result = try await group.next() {
					results.append(result)
				}
				return results
			}
			print("Loaded \(notes.count) notes from vault")
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
				.frame(maxWidth: .infinity, alignment: .leading)
			
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
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}

// Simple split view implementations
struct HSplitView<Content: View>: View {
	let spacing: CGFloat
	let content: Content
	
	init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
		self.spacing = spacing
		self.content = content()
	}
	
	var body: some View {
		HStack(spacing: spacing) {
			content
		}
	}
}

struct VSplitView<Content: View>: View {
	let spacing: CGFloat
	let content: Content
	
	init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
		self.spacing = spacing
		self.content = content()
	}
	
	var body: some View {
		VStack(spacing: spacing) {
			content
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
			.frame(maxWidth: .infinity)
			
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
			.frame(maxWidth: .infinity, maxHeight: .infinity)
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
	
	// Extract internal links like [[note name]]
	var internalLinks: [String] {
		let pattern = "\\[\\[([\\w\\s-]+)\\]\\]"
		guard let regex = try? NSRegularExpression(pattern: pattern) else {
			return []
		}
		
		let text = content
		let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
		return matches.compactMap { match in
			guard match.numberOfRanges >= 2 else { return nil }
			let linkRange = Range(match.range(at: 1), in: text)
			return linkRange.map { String(text[$0]).trimmingCharacters(in: .whitespaces) }
		}
	}
	
	// Bidirectional links (notes that link to this one)
	var backlinks: [String] {
		return [] // Will be computed later from vault
	}
	
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
