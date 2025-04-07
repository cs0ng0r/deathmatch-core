// DM Core HUD Script

// Variables
let hudVisible = true;

// Initialize when resource is ready
window.addEventListener('load', function() {
    window.addEventListener('message', function(event) {
        let data = event.data;

        if (data.type === 'update') {
            updateHUD(data);
        } else if (data.type === 'toggle') {
            toggleHUD(data.show);
        } else if (data.type === 'notification') {
            showNotification(data.message, data.notificationType, data.duration);
        }
    });
});

// Update HUD with new data
function updateHUD(data) {
    if (data.money) {
        document.getElementById('cash').textContent = '$' + formatNumber(data.money.cash || 0);
        document.getElementById('bank').textContent = '$' + formatNumber(data.money.bank || 0);
    }
    
    if (data.stats) {
        document.getElementById('kills').textContent = data.stats.kills || 0;
        document.getElementById('deaths').textContent = data.stats.deaths || 0;
        
        // Calculate K/D ratio
        const kills = parseInt(data.stats.kills) || 0;
        const deaths = parseInt(data.stats.deaths) || 0;
        let kdRatio = 0;
        
        if (deaths > 0) {
            kdRatio = kills / deaths;
        } else if (kills > 0) {
            kdRatio = kills;
        }
        
        document.getElementById('kd-ratio').textContent = kdRatio.toFixed(2);
    }
    
    if (data.weapon) {
        document.getElementById('weapon-name').textContent = data.weapon.name || '-';
        document.getElementById('ammo-count').textContent = data.weapon.ammo || 0;
        document.getElementById('ammo-max').textContent = data.weapon.ammoMax || 0;
    }
    
    if (data.location) {
        document.getElementById('street-name').textContent = data.location.street || 'Unknown Road';
        document.getElementById('zone-name').textContent = data.location.zone || 'Los Santos';
    }
}

// Toggle HUD visibility
function toggleHUD(visible) {
    hudVisible = visible !== undefined ? visible : !hudVisible;
    
    const elements = ['player-info', 'weapon-info', 'location-display'];
    elements.forEach(id => {
        document.getElementById(id).classList.toggle('hidden', !hudVisible);
    });
}

// Show notification
function showNotification(message, type = 'info', duration = 5000) {
    const container = document.getElementById('notification-container');
    const notification = document.createElement('div');
    
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    container.appendChild(notification);
    
    setTimeout(() => {
        notification.style.opacity = '0';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, duration);
}

// Format number with commas
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// DEBUG: Test functions (can be removed in production)
/*
window.addEventListener('keydown', function(e) {
    if (e.key === 'h') toggleHUD();
    if (e.key === 'n') showNotification('Test notification', 'info', 3000);
});
*/