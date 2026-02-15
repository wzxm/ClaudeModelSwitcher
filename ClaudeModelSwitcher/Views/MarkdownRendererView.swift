//
//  MarkdownRendererView.swift
//  ClaudeModelSwitcher
//
//  Markdown 渲染视图 - 使用 WKWebView 渲染 Markdown 内容
//

import SwiftUI
import WebKit

/// 将 Markdown 文本渲染为富文本显示的视图
struct MarkdownRendererView: NSViewRepresentable {
    let content: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = wrapInHTML(content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - 生成 HTML

    /// 简易 Markdown -> HTML 转换，嵌入样式
    private func wrapInHTML(_ markdown: String) -> String {
        let bodyHTML = convertMarkdownToHTML(markdown)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root {
                color-scheme: light dark;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                font-size: 13px;
                line-height: 1.6;
                color: #e0e0e0;
                padding: 16px 20px;
                margin: 0;
                background: transparent;
            }
            @media (prefers-color-scheme: light) {
                body { color: #333; }
                code { background: #f0f0f0; color: #333; }
                pre { background: #f5f5f5; border-color: #e0e0e0; }
                pre code { background: transparent; color: #333; }
                blockquote { border-left-color: #ccc; color: #666; }
                h1, h2, h3, h4 { color: #222; }
                hr { border-color: #ddd; }
                a { color: #0969da; }
                table th { background: #f0f0f0; }
                table td, table th { border-color: #d0d0d0; }
            }
            h1, h2, h3, h4 {
                color: #fff;
                margin-top: 1.2em;
                margin-bottom: 0.5em;
            }
            h1 { font-size: 1.6em; border-bottom: 1px solid #333; padding-bottom: 6px; }
            h2 { font-size: 1.3em; border-bottom: 1px solid #333; padding-bottom: 4px; }
            h3 { font-size: 1.1em; }
            h4 { font-size: 1em; }
            p { margin: 0.6em 0; }
            code {
                font-family: "SF Mono", Menlo, monospace;
                font-size: 0.9em;
                background: #2a2a2a;
                color: #4ec9b0;
                padding: 1px 5px;
                border-radius: 3px;
            }
            pre {
                background: #1e1e1e;
                border: 1px solid #333;
                border-radius: 6px;
                padding: 12px 14px;
                overflow-x: auto;
                margin: 0.8em 0;
            }
            pre code {
                background: transparent;
                color: #d4d4d4;
                padding: 0;
            }
            ul, ol {
                padding-left: 1.5em;
                margin: 0.5em 0;
            }
            li { margin: 0.2em 0; }
            blockquote {
                border-left: 3px solid #555;
                color: #aaa;
                margin: 0.8em 0;
                padding: 4px 14px;
            }
            hr {
                border: none;
                border-top: 1px solid #444;
                margin: 1em 0;
            }
            a {
                color: #58a6ff;
                text-decoration: none;
            }
            a:hover { text-decoration: underline; }
            strong { font-weight: 600; }
            table {
                border-collapse: collapse;
                margin: 0.8em 0;
                width: 100%;
            }
            table th, table td {
                border: 1px solid #444;
                padding: 6px 10px;
                text-align: left;
            }
            table th {
                background: #2a2a2a;
                font-weight: 600;
            }
        </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    /// 简易 Markdown 到 HTML 转换
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var inList = false
        var listType = ""  // "ul" 或 "ol"

        for i in 0..<lines.count {
            let line = lines[i]

            // 代码块处理
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "<pre><code>\(escapeHTML(codeBlockContent))</code></pre>\n"
                    codeBlockContent = ""
                    inCodeBlock = false
                } else {
                    if inList {
                        html += "</\(listType)>\n"
                        inList = false
                    }
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent += (codeBlockContent.isEmpty ? "" : "\n") + line
                continue
            }

            // 空行
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if inList {
                    html += "</\(listType)>\n"
                    inList = false
                }
                continue
            }

            // 标题
            if line.hasPrefix("#### ") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<h4>\(processInline(String(line.dropFirst(5))))</h4>\n"
                continue
            }
            if line.hasPrefix("### ") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<h3>\(processInline(String(line.dropFirst(4))))</h3>\n"
                continue
            }
            if line.hasPrefix("## ") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<h2>\(processInline(String(line.dropFirst(3))))</h2>\n"
                continue
            }
            if line.hasPrefix("# ") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<h1>\(processInline(String(line.dropFirst(2))))</h1>\n"
                continue
            }

            // 水平线
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("---") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<hr>\n"
                continue
            }

            // 引用
            if line.hasPrefix("> ") {
                if inList { html += "</\(listType)>\n"; inList = false }
                html += "<blockquote>\(processInline(String(line.dropFirst(2))))</blockquote>\n"
                continue
            }

            // 无序列表
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                if !inList || listType != "ul" {
                    if inList { html += "</\(listType)>\n" }
                    html += "<ul>\n"
                    inList = true
                    listType = "ul"
                }
                let content = String(trimmedLine.dropFirst(2))
                html += "<li>\(processInline(content))</li>\n"
                continue
            }

            // 有序列表
            if let dotRange = trimmedLine.range(of: ". "),
               let _ = Int(trimmedLine[trimmedLine.startIndex..<dotRange.lowerBound]) {
                if !inList || listType != "ol" {
                    if inList { html += "</\(listType)>\n" }
                    html += "<ol>\n"
                    inList = true
                    listType = "ol"
                }
                let content = String(trimmedLine[dotRange.upperBound...])
                html += "<li>\(processInline(content))</li>\n"
                continue
            }

            // 普通段落
            if inList { html += "</\(listType)>\n"; inList = false }
            html += "<p>\(processInline(line))</p>\n"
        }

        // 关闭未结束的块
        if inCodeBlock {
            html += "<pre><code>\(escapeHTML(codeBlockContent))</code></pre>\n"
        }
        if inList {
            html += "</\(listType)>\n"
        }

        return html
    }

    /// 处理行内元素：加粗、斜体、行内代码、链接
    private func processInline(_ text: String) -> String {
        var result = escapeHTML(text)

        // 行内代码 `code`
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // 加粗 **text**
        result = result.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // 斜体 *text*（避免匹配加粗后的 strong 标签）
        result = result.replacingOccurrences(
            of: "(?<!\\*)\\*([^*]+)\\*(?!\\*)",
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // 链接 [text](url)
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        return result
    }

    /// HTML 转义
    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
