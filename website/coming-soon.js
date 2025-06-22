// ABOUTME: JavaScript for coming soon pages - handles email notifications
// ABOUTME: Manages form submissions and user feedback

function handleNotifySubmit(event) {
    event.preventDefault();
    
    const form = event.target;
    const emailInput = form.querySelector('.email-input');
    const button = form.querySelector('.notify-button');
    const email = emailInput.value;
    
    // Disable form during submission
    emailInput.disabled = true;
    button.disabled = true;
    button.textContent = 'Submitting...';
    
    // Simulate API call (in production, this would send to your backend)
    setTimeout(() => {
        // Show success message
        const successMessage = document.createElement('div');
        successMessage.className = 'success-message';
        successMessage.textContent = `✅ Thanks! We'll notify ${email} when OpenVine launches!`;
        successMessage.style.cssText = `
            background: #0ae68a;
            color: white;
            padding: 1rem;
            border-radius: 10px;
            margin-top: 1rem;
            animation: slideIn 0.3s ease-out;
        `;
        
        form.appendChild(successMessage);
        
        // Reset form
        emailInput.value = '';
        emailInput.disabled = false;
        button.disabled = false;
        button.textContent = 'Notify Me';
        
        // Remove success message after 5 seconds
        setTimeout(() => {
            successMessage.style.animation = 'slideOut 0.3s ease-in';
            setTimeout(() => {
                successMessage.remove();
            }, 300);
        }, 5000);
        
        // Log for demo purposes
        console.log(`Email ${email} added to waitlist`);
    }, 1000);
}

// Add animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            opacity: 0;
            transform: translateY(-10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    @keyframes slideOut {
        from {
            opacity: 1;
            transform: translateY(0);
        }
        to {
            opacity: 0;
            transform: translateY(-10px);
        }
    }
    
    .success-message {
        animation: slideIn 0.3s ease-out;
    }
`;
document.head.appendChild(style);

// Animate progress bar on page load
document.addEventListener('DOMContentLoaded', function() {
    const progressBar = document.querySelector('.progress-bar');
    if (progressBar) {
        // Start at 0 width
        progressBar.style.width = '0%';
        
        // Animate to target width after a short delay
        setTimeout(() => {
            progressBar.style.width = progressBar.getAttribute('style').match(/width:\s*(\d+%)/)[1];
        }, 100);
    }
    
    // Add hover effect to device mockups
    const deviceMockup = document.querySelector('.device-mockup');
    if (deviceMockup) {
        deviceMockup.addEventListener('mouseover', function() {
            this.style.transform = 'scale(1.05)';
            this.style.transition = 'transform 0.3s ease';
        });
        
        deviceMockup.addEventListener('mouseout', function() {
            this.style.transform = 'scale(1)';
        });
    }
});