import SwiftUI

// MARK: - CategoryManagerView
/// Screen for creating, editing, and deleting categories.
struct CategoryManagerView: View {
    
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var newCategoryName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Match light theme used in other tabs
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.98, green: 0.98, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                List {
                // ADD NEW CATEGORY
                Section(header: Text("Create New Category").foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))) {
                    HStack(spacing: 12) {
                        TextField("Category Name (e.g., Sports, Movies)", text: $newCategoryName)
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            .accentColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                        
                        Button(action: {
                            createCategory()
                        }) {
                            Circle()
                                .fill(Color(red: 0.91, green: 0.27, blue: 0.38))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
#if os(tvOS)
                        .buttonStyle(.card)
#else
                        .buttonStyle(.plain)
#endif
                        .disabled(newCategoryName.isEmpty)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white)
                }
                
                // EXISTING CATEGORIES
                Section(header: Text("Existing Categories").foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))) {
                    ForEach($playlistManager.categories) { $category in
                        CategoryRow(category: $category, viewModel: viewModel, onDelete: {
                            deleteCategory($category.wrappedValue)
                        })
                            .listRowBackground(Color.white)
                    }
                    // Deletion triggered by swipe or Edit button
                    .onDelete(perform: deleteCategory)
                }
                }
                #if os(iOS)
                .scrollContentBackground(.hidden)
                #endif
                .background(Color.clear)
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Categories")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(hex: "e94560"))
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(Color(hex: "e94560"))
                }
                #endif
            }
        }
    }
    
    private func createCategory() {
        guard !newCategoryName.isEmpty else { return }
        _ = playlistManager.addCategory(name: newCategoryName)
        newCategoryName = ""
    }
    
    private func deleteCategory(_ category: ChannelCategory) {
        let categoryId = category.id
        
        // CRITICAL: Remove this category from all channels
        viewModel.channels = viewModel.channels.map { channel in
            var updatedChannel = channel
            updatedChannel.categoryIDs.remove(categoryId)
            return updatedChannel
        }
        
        // Save updated channels
        playlistManager.saveChannels(viewModel.channels)
        
        // Permanently remove the category from PlaylistManager
        playlistManager.deleteCategory(id: categoryId)
        
        if let index = playlistManager.categories.firstIndex(where: { $0.id == categoryId }) {
            playlistManager.categories.remove(at: index)
        }
        
        print("🗑️ Deleted category and removed from all channels")
    }

    func deleteCategory(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { index in
            let category = playlistManager.categories[index]
            deleteCategory(category)
        }
    }
}
    
// MARK: - CategoryRow (Row View)
struct CategoryRow: View {
    
    @Binding var category: ChannelCategory
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var isEditing = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 15) {
            // Folder icon
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
            
            if isEditing {
                TextField("Category Name", text: $category.name)
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .accentColor(Color(red: 0.91, green: 0.27, blue: 0.38))
            } else {
                Text(category.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
            }
            
            Spacer()
            
            // Edit/Save Button
            HStack(spacing: 10) {
                Button(action: {
                    toggleEditing()
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isEditing ? Color(red: 0.31, green: 0.66, blue: 0.87) : Color(red: 0.91, green: 0.27, blue: 0.38))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background((isEditing ? Color(red: 0.31, green: 0.66, blue: 0.87) : Color(red: 0.91, green: 0.27, blue: 0.38)).opacity(0.18))
                        .cornerRadius(10)
                }
#if os(tvOS)
                .buttonStyle(.card)
#endif
                
                if isEditing {
                    Button(action: {
                        onDelete?()
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.18))
                            .cornerRadius(10)
                    }
#if os(tvOS)
                    .buttonStyle(.card)
#endif
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func toggleEditing() {
        withAnimation {
            isEditing.toggle()
            if !isEditing {
                playlistManager.updateCategory(category: category, newName: category.name)
            }
        }
    }
}

