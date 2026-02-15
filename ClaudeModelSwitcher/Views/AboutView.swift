//
//  AboutView.swift
//  ClaudeModelSwitcher
//
//  关于页面
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            // 应用名称
            Text("Claude Model Switcher")
                .font(.title)
                .fontWeight(.bold)

            // 版本信息
            Text("版本 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 描述
            Text("快速切换 Claude Code 使用的模型")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("支持 Anthropic 官方 API 和 OpenRouter 平台")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // 底部信息
            VStack(spacing: 8) {
                Text("Made with ❤️ by 老王")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link("GitHub", destination: URL(string: "https://github.com/wzxm")!)
                    .font(.caption)
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AboutView()
        .frame(width: 500, height: 400)
}
