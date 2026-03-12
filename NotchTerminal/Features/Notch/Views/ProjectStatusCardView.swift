import SwiftUI

public struct ProjectStatusCardView: View {
    @ObservedObject var gitStatus: GitStatusService
    let projectName: String?
    let showFolder: Bool
    let showGit: Bool
    let isFloating: Bool
    
    public init(gitStatus: GitStatusService, projectName: String?, showFolder: Bool = true, showGit: Bool = true, isFloating: Bool = false) {
        self.gitStatus = gitStatus
        self.projectName = projectName
        self.showFolder = showFolder
        self.showGit = showGit
        self.isFloating = isFloating
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Project Name
            if showFolder, let name = projectName {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue.opacity(0.8))
                    Text(name)
                        .fontWeight(.medium)
                }
                if showGit, gitStatus.status.branchName != nil {
                    Divider()
                        .frame(height: 12)
                        .background(Color.white.opacity(0.2))
                }
            }
            
            // Git Branch
            if showGit, let branch = gitStatus.status.branchName {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(branch)
                        .foregroundStyle(gitStatus.status.hasPendingChanges ? .yellow : .white)
                    
                    if gitStatus.status.hasPendingChanges {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .font(.system(size: 11, weight: .regular, design: .rounded))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isFloating ? Color.black.opacity(0.85) : Color.clear, in: Capsule())
        .overlay(
            Group {
                if isFloating {
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        )
    }
}
