// swagger.v - Swagger UI 中间件
// 本模块提供 Swagger UI 文档界面功能，类似于 Hono.js 的 @hono/swagger-ui 中间件
// 支持 OpenAPI 3.0/3.1 规范
module hono

import net.http

// ============================================================================
// Swagger UI 配置选项 (Task 7.1)
// ============================================================================

// SwaggerUIOptions - Swagger UI 配置选项
// 使用示例:
//   app.get('/ui', hono.swagger_ui(hono.SwaggerUIOptions{ url: '/doc' }))
pub struct SwaggerUIOptions {
pub mut:
	url                         string = '/doc'  // OpenAPI 文档 URL
	title                       string = 'API Documentation'  // 页面标题
	deep_linking                bool   = true   // 启用深度链接
	display_request_duration    bool   = true   // 显示请求耗时
	default_models_expand_depth int    = 1      // 模型展开深度
	doc_expansion               string = 'list' // 文档展开方式: 'list', 'full', 'none'
	filter                      bool            // 启用过滤
	show_extensions             bool            // 显示扩展
	show_common_extensions      bool   = true   // 显示常用扩展
	try_it_out_enabled          bool   = true   // 启用 Try it out
	custom_css                  string          // 自定义 CSS
	custom_js                   string          // 自定义 JavaScript
	custom_css_url              string          // 自定义 CSS URL
	custom_js_url               string          // 自定义 JavaScript URL
}


// ============================================================================
// Swagger UI HTML 生成 (Task 7.2)
// ============================================================================

// generate_swagger_html - 生成 Swagger UI HTML 页面
// 使用 CDN 链接加载 Swagger UI 资源
// 应用配置选项到 SwaggerUIBundle 配置
fn generate_swagger_html(options SwaggerUIOptions) string {
	// 构建自定义 CSS URL 标签
	custom_css_url_tag := if options.custom_css_url.len > 0 {
		'<link rel="stylesheet" href="${options.custom_css_url}">'
	} else {
		''
	}

	// 构建自定义 JS URL 标签
	custom_js_url_tag := if options.custom_js_url.len > 0 {
		'<script src="${options.custom_js_url}"></script>'
	} else {
		''
	}

	// 构建自定义 CSS 内联样式
	custom_css_inline := if options.custom_css.len > 0 {
		options.custom_css
	} else {
		''
	}

	// 构建自定义 JS 内联脚本
	custom_js_inline := if options.custom_js.len > 0 {
		options.custom_js
	} else {
		''
	}

	// 转换布尔值为 JavaScript 字符串
	deep_linking_str := if options.deep_linking { 'true' } else { 'false' }
	display_request_duration_str := if options.display_request_duration { 'true' } else { 'false' }
	filter_str := if options.filter { 'true' } else { 'false' }
	show_extensions_str := if options.show_extensions { 'true' } else { 'false' }
	show_common_extensions_str := if options.show_common_extensions { 'true' } else { 'false' }
	try_it_out_enabled_str := if options.try_it_out_enabled { 'true' } else { 'false' }

	return '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${options.title}</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    ${custom_css_url_tag}
    <style>
        html { box-sizing: border-box; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; background: #fafafa; }
        ${custom_css_inline}
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    ${custom_js_url_tag}
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "${options.url}",
                dom_id: \'#swagger-ui\',
                deepLinking: ${deep_linking_str},
                displayRequestDuration: ${display_request_duration_str},
                defaultModelsExpandDepth: ${options.default_models_expand_depth},
                docExpansion: "${options.doc_expansion}",
                filter: ${filter_str},
                showExtensions: ${show_extensions_str},
                showCommonExtensions: ${show_common_extensions_str},
                tryItOutEnabled: ${try_it_out_enabled_str},
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
            });
            window.ui = ui;
        };
        ${custom_js_inline}
    </script>
</body>
</html>'
}


// ============================================================================
// Swagger UI 中间件函数 (Task 7.3)
// ============================================================================

// swagger_ui - 创建 Swagger UI 处理器
// 返回处理器函数，设置正确的 Content-Type，返回生成的 HTML
// 使用示例:
//   app.get('/ui', hono.swagger_ui(hono.SwaggerUIOptions{ url: '/doc' }))
//   app.get('/docs', hono.swagger_ui())  // 使用默认选项
pub fn swagger_ui(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	// 获取选项，如果没有提供则使用默认值
	opts := if options.len > 0 {
		options[0]
	} else {
		SwaggerUIOptions{}
	}

	// 预生成 HTML 内容
	html_content := generate_swagger_html(opts)

	return fn [html_content] (mut c Context) http.Response {
		return http.Response{
			status_code: 200
			header:      http.new_header(key: .content_type, value: 'text/html; charset=utf-8')
			body:        html_content
		}
	}
}

// swagger_ui_handler - swagger_ui 的别名函数
// 使用示例:
//   app.get('/swagger', hono.swagger_ui_handler(hono.SwaggerUIOptions{ url: '/api/doc' }))
pub fn swagger_ui_handler(options ...SwaggerUIOptions) fn (mut Context) http.Response {
	return swagger_ui(...options)
}
