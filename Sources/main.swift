import Foundation
import SlackKit
import Alamofire
import SWXMLHash

class BotRocks {
    
    let bot: SlackKit
    let appId = "458368812"
    var commentsTimer : Timer?
    var lastCommentsId = ""
    var channels = [String]()
    
    init(token: String) {
        bot = SlackKit()
        bot.addRTMBotWithAPIToken(token)
        bot.addWebAPIAccessWithToken(token)
        bot.notificationForEvent(.message) { [weak self] (event, client) in
            if let message = event.message{
                self?.handleMessage(message)
            }
        }
    }

    init(clientID: String, clientSecret: String) {
        bot = SlackKit()
        let oauthConfig = OAuthConfig(clientID: clientID, clientSecret: clientSecret)
        bot.addServer(oauth: oauthConfig)
        bot.notificationForEvent(.message) { [weak self] (event, client) in
            guard
                let message = event.message,
                let id = client?.authenticatedUser?.id,
                message.text?.contains(id) == true
                else {
                    return
            }
            self?.handleMessage(message)
        }
    }
    
    // MARK: Bot logic
    private func handleMessage(_ message: Message) {
        if let text = message.text?.lowercased(), let timestamp = message.ts, let channel = message.channel {
            
            if text.contains("димон"){
                bot.webAPI?.addReactionToMessage(name: "boomer_dimon", channel: channel, timestamp: timestamp, success: nil, failure: nil)
                return
            }
            
            if text.contains("app_reviews_start"){
                
                if !channels.contains(channel){
                self.bot.webAPI?.sendMessage(channel: channel, text: "Вы успешно подписаны на отзывы к приложению Biglion. Скоро в этом канале появятся первые отзывы 🙌", success: { (_: (ts: String?, channel: String?)) in
                    if self.commentsTimer == nil{
                        self.commentsTimer = Timer.scheduledTimer(timeInterval: TimeInterval.init(3600), target: self, selector: #selector(self.getFreshComments), userInfo: nil, repeats: true)
                            self.channels.append(message.channel!)
                            self.saveChannelsList(channels: self.channels)
                    }
                    self.getFreshComments()
                    return
                }, failure: { (error) in
                    return
                    })
                } else{
                    self.bot.webAPI?.sendMessage(channel: channel, text: "Вы уже подписаны на отзывы к приложению Biglion 😛", success: nil, failure: { (error) in
                        return
                    })

                }
            }
            
            if text.contains("app_reviews_stop"){
                var channelsCopy = channels
                var objectIndex = 0
                for channel in channels{
                    if channel == message.channel{
                        channelsCopy.remove(at: objectIndex)
                        self.bot.webAPI?.sendMessage(channel: channel, text: "Вы успешно отписаны от отзывов к приложению Biglion 😊", success: nil, failure: { (error) in
                            print(error)
                        })
                    }
                    objectIndex += 1
                }
                channels = channelsCopy
                self.saveChannelsList(channels: channels)
                return
            }
            return
        }
    }
    
    @objc func getFreshComments(){
        self.lastCommentsId = self.getLastReviewId()
        let appCommentsUrl = String.localizedStringWithFormat("https://itunes.apple.com/ru/rss/customerreviews/id=%@/sortBy=mostRecent/xml", appId)
        Alamofire.request(appCommentsUrl).response { (response) in
            let xmlParsed = SWXMLHash.parse(response.data!)
            var reviewsArray = [Review]()
            for comment in xmlParsed.children[0].children{
                var review = Review.init()
                review.authorName = comment["author"]["name"].description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                review.title = comment["title"].description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                review.text = comment["content"][0].description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                review.uri = comment["author"]["uri"].description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                review.raiting = Int.init(comment["im:rating"].description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil))
                if review.raiting != nil{
                    for _ in 0 ..< review.raiting!{
                        review.stars.append(" :star:")
                    }
                }
                if review.uri != "" {
                    reviewsArray.insert(review, at: 0)
                }
            }
            if let lastUri = reviewsArray.last?.uri{
                if lastUri != self.lastCommentsId{
                    self.lastCommentsId = lastUri
                    self.saveLastReviewId(reviewId: lastUri)
                    for review in reviewsArray{
                        for channel in self.channels{
                            self.bot.webAPI?.sendMessage(channel: channel, text: String.localizedStringWithFormat("%@\n%@\n%@\n\n", review.title ?? "", review.text ?? "", review.stars),username: review.authorName, success: nil, failure: { (error) in
                                print(error)
                            })
                        }
                    }
                }
            }
        }
    }

    private func saveLastReviewId(reviewId: String){
            if let path = Bundle.main.path(forResource: "settings", ofType: "plist"){
            let fileManager = FileManager.default
            if(!fileManager.fileExists(atPath: path)){
                if let bundlePath = Bundle.main.path(forResource: "settings", ofType: "plist"){
                    let result = NSMutableDictionary(contentsOfFile: bundlePath)
                        print("Bundle file settings.plist is -> \(result?.description ?? "")")
                    do{
                        try fileManager.copyItem(atPath: bundlePath, toPath: path)
                    }catch{
                        print("copy failure.")
                    }
                }else{
                    print("file settings.plist not found.")
                }
            }else{
                print("file settings.plist already exits at path.")
            }
            
            let resultDictionary = NSMutableDictionary(contentsOfFile: path)
            resultDictionary?.setObject(reviewId, forKey: "lastReviewId" as NSCopying)
            resultDictionary?.write(toFile: path, atomically: true)
        }
    }
    
    private func saveChannelsList(channels: [String]){
        if let path = Bundle.main.path(forResource: "settings", ofType: "plist"){
            let fileManager = FileManager.default
            if(!fileManager.fileExists(atPath: path)){
                if let bundlePath = Bundle.main.path(forResource: "settings", ofType: "plist"){
                    let result = NSMutableDictionary(contentsOfFile: bundlePath)
                    print("Bundle file settings.plist is -> \(result?.description ?? "")")
                    do{
                        try fileManager.copyItem(atPath: bundlePath, toPath: path)
                    }catch{
                        print("copy failure.")
                    }
                }else{
                    print("file settings.plist not found.")
                }
            }else{
                print("file settings.plist already exits at path.")
            }
            
            let resultDictionary = NSMutableDictionary(contentsOfFile: path)
            resultDictionary?.setObject(channels, forKey: "channels" as NSCopying)
            resultDictionary?.write(toFile: path, atomically: true)
        }
    }
    
    private func getLastReviewId() -> String{
        if let path = Bundle.main.path(forResource: "settings", ofType: "plist"){
        let fileManager = FileManager.default
        if(!fileManager.fileExists(atPath: path)){
            if let bundlePath = Bundle.main.path(forResource: "settings", ofType: "plist"){
                let result = NSMutableDictionary(contentsOfFile: bundlePath)
                    print("Bundle file settings.plist is -> \(result?.description ?? "")")
                do{
                    try fileManager.copyItem(atPath: bundlePath, toPath: path)
                }catch{
                    print("copy failure.")
                }
            }else{
                print("file settings.plist not found.")
            }
        }else{
            print("file settings.plist already exits at path.")
        }
        
        let resultDictionary = NSMutableDictionary(contentsOfFile: path)
        if let reviewId = resultDictionary?.value(forKey: "lastReviewId") as? String{
            return reviewId
            }
        }
        return ""
    }
    
    private func getLastChannels() -> [String]{
        if let path = Bundle.main.path(forResource: "settings", ofType: "plist"){
            let fileManager = FileManager.default
            if(!fileManager.fileExists(atPath: path)){
                if let bundlePath = Bundle.main.path(forResource: "settings", ofType: "plist"){
                    let result = NSMutableDictionary(contentsOfFile: bundlePath)
                    print("Bundle file settings.plist is -> \(result?.description ?? "")")
                    do{
                        try fileManager.copyItem(atPath: bundlePath, toPath: path)
                    }catch{
                        print("copy failure.")
                    }
                }else{
                    print("file settings.plist not found.")
                }
            }else{
                print("file settings.plist already exits at path.")
            }
            
            let resultDictionary = NSMutableDictionary(contentsOfFile: path)
            if let channels = resultDictionary?.value(forKey: "channels") as? [String]{
                return channels
            }
        }
        return [""]
    }
    
    struct Review {
        var title : String?
        var text : String?
        var uri : String?
        var authorName : String?
        var raiting : Int?
        var stars = ""
    }

}

// With API token
let slackbot = BotRocks(token: "xoxb-245840761351-CiH8bmts4GQDgC3D9mUTnmKk")

RunLoop.main.run()
    
