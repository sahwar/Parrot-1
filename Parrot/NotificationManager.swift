import Cocoa

/* TODO: Switch to a Disk LRU Cache instead of Dictionary. */

// Internal NSImage cache, and
private var _cache = Dictionary<String, NSData>()
private var _notes = Dictionary<String, [String]>()

// Quick alias just for us.
private let nc = NSUserNotificationCenter.default()

// The default user image, when none can be located.
public let defaultUserImage = NSImage(named: "NSUserGuest")!

public class NotificationManager: NSObject, NSUserNotificationCenterDelegate {
    static let sharedInstance = NotificationManager()

    public override init() {
        super.init()
        nc.delegate = self
    }
	
	// Overrides notification identifier
	public func sendNotificationFor(group: (group: String, item: String), notification: NSUserNotification) {
        let conversationID = group.0
        let notificationID = group.1
        notification.identifier = notificationID
		
        var notificationIDs = _notes[conversationID]
        if notificationIDs != nil {
            notificationIDs!.append(notificationID)
            _notes[conversationID] = notificationIDs
        } else {
            _notes[conversationID] = [notificationID]
        }
        nc.deliver(notification)
		
		let vibrate = Settings()[Parrot.VibrateForceTouch] as? Bool ?? false
		if vibrate {
			let length = 1000
			let interval = 10
			
			let hp = NSHapticFeedbackManager.defaultPerformer()
			for _ in 1...(length/interval) {
				hp.perform(.generic, performanceTime: .now)
				usleep(10 * 1000)
			}
		}
    }

    public func clearNotificationsFor(group: String) {
        for notificationID in (_notes[group] ?? []) {
            let notification = NSUserNotification()
            notification.identifier = notificationID
            nc.removeDeliveredNotification(notification)
        }
        _notes.removeValue(forKey: group)
	}
	
	// Handle NSApp dock badge.
	
	public class func updateAppBadge(messages: Int) {
		NSApp.dockTile.badgeLabel = messages > 0 ? "\(messages)" : ""
	}
	
	// Handle NSUserNotificationCenter delivery.
	
    public func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
		
    }
	
	public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
		
	}

    public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

// Note that this is general purpose! It needs a unique ID and a resource URL string.
public func fetchData(id: String?, _ resource: String?, handler: ((NSData?) -> Void)? = nil) -> NSData? {
	
	// Case 1: No unique ID -> bail.
	guard let id = id else {
		handler?(nil)
		return nil
	}
	
	// Case 2: We've already fetched it -> return image.
	if let img = _cache[id] {
		handler?(img)
		return img
	}
	
	// Case 3: No resource URL -> bail.
	guard let photo_url = resource, let url = NSURL(string: photo_url) else {
		handler?(nil)
		return nil
	}
	
	// Case 4: We can request the resource -> return image.
	let semaphore = Semaphore(count: 0)
	NSURLSession.shared().request(request: NSURLRequest(url: url)) {
		if let data = $0.data {
			_cache[id] = data
			handler?(data)
			semaphore.signal()
		}
	}
	
	// Onlt wait on the semaphore if we don't have a handler.
	if handler == nil {
		semaphore.wait()
		return _cache[id]
	} else {
		return nil
	}
}
