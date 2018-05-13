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