// V-Hono Static File Server - JavaScript Example

console.log('🚀 V-Hono Static File Server loaded!');

// 演示动态内容加载
document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DOM loaded successfully');
    
    // 添加一些交互功能
    const features = document.querySelectorAll('.feature-list li');
    
    features.forEach((feature, index) => {
        feature.addEventListener('click', function() {
            this.style.transform = 'scale(1.05)';
            this.style.transition = 'transform 0.2s ease';
            
            setTimeout(() => {
                this.style.transform = 'scale(1)';
            }, 200);
            
            console.log(`✨ Feature ${index + 1} clicked: ${this.textContent}`);
        });
    });
    
    // 添加时间戳
    const timestamp = new Date().toLocaleString('zh-CN');
    console.log(`⏰ Page loaded at: ${timestamp}`);
    
    // 检查静态文件服务状态
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            console.log('📊 Server status:', data);
        })
        .catch(error => {
            console.log('❌ Error fetching status:', error);
        });
});

// 工具函数
function showMessage(message, type = 'info') {
    const colors = {
        info: '#4CAF50',
        warning: '#FF9800',
        error: '#F44336'
    };
    
    console.log(`%c${message}`, `color: ${colors[type]}; font-weight: bold;`);
}

// 导出一些工具函数供其他脚本使用
window.VHonoUtils = {
    showMessage,
    getTimestamp: () => new Date().toISOString(),
    logFeature: (featureName) => showMessage(`Feature used: ${featureName}`, 'info')
}; 