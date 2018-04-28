// request permission on page load
document.addEventListener('DOMContentLoaded', function () {
    if (!Notification) {
        alert('Desktop notifications not available in your browser. Try Chromium.');
        return;
    }

    if (Notification.permission !== "granted")
        Notification.requestPermission();
});

function notifyMe(Title, Icon, Body, Tab) {
    if (Notification.permission !== "granted")
        Notification.requestPermission();
    else {
        var notification = new Notification(Title, {
            icon: Icon,
            body: Body
        });

        notification.onclick = function () {
            Tab.click();
            window.focus();
            notification.close();
        };

    }

}