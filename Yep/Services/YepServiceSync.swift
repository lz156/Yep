//
//  YepServiceSync.swift
//  Yep
//
//  Created by NIX on 15/3/20.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import Foundation
import RealmSwift


let YepNewMessagesReceivedNotification = "YepNewMessagesReceivedNotification"

enum MessageAge: String {
    case Old
    case New
}

func tryPostNewMessagesReceivedNotificationWithMessageIDs(messageIDs: [String], withMessageAge messageAge: MessageAge) {

    if !messageIDs.isEmpty {
        dispatch_async(dispatch_get_main_queue()) {
            let object = [
                "messageIDs": messageIDs,
                "messageAge": messageAge.rawValue,
            ]
            NSNotificationCenter.defaultCenter().postNotificationName(YepNewMessagesReceivedNotification, object: object)
        }
    }
}

func getOrCreateUserWithDiscoverUser(discoveredUser: DiscoveredUser, inRealm realm: Realm) -> User? {
    
    var user = userWithUserID(discoveredUser.id, inRealm: realm)

    if user == nil {
        let newUser = User()
        
        newUser.userID = discoveredUser.id
        
        newUser.friendState = UserFriendState.Stranger.rawValue

        let _ = try? realm.write {
            realm.add(newUser)
        }

        user = newUser
    }
    
    if let user = user {
        
        let _ = try? realm.write {

            // 只更新用户信息即可

            user.lastSignInUnixTime = discoveredUser.lastSignInUnixTime

            user.username = discoveredUser.username ?? ""

            user.nickname = discoveredUser.nickname

            if let introduction = discoveredUser.introduction {
                user.introduction = introduction
            }

            user.avatarURLString = discoveredUser.avatarURLString

            user.longitude = discoveredUser.longitude

            user.latitude = discoveredUser.latitude
            
            if let badge = discoveredUser.badge {
                user.badge = badge
            }
        }
    }

    return user
}

func skillsFromUserSkillList(userSkillList: List<UserSkill>) -> [Skill] {

    var userSkills = [UserSkill]()

    for userSkill in userSkillList {
        userSkills.append(userSkill)
    }
    
    return userSkills.map({ userSkill -> Skill in

        var skillCategory: SkillCategory?

        if let category = userSkill.category {
            skillCategory = SkillCategory(id: category.skillCategoryID, name: category.name, localName: category.localName, skills: [])
        }

        let skill = Skill(category: skillCategory, id: userSkill.skillID, name: userSkill.name, localName: userSkill.localName, coverURLString: userSkill.coverURLString)

        return skill
    })
}

func attachmentFromDiscoveredAttachment(discoverAttachments: [DiscoveredAttachment], inRealm realm: Realm?) -> [Attachment]{

    return discoverAttachments.map({ discoverAttachment -> Attachment? in
        
        let newAttachment = Attachment()
        newAttachment.kind = discoverAttachment.kind.rawValue
        newAttachment.metadata = discoverAttachment.metadata
        newAttachment.URLString = discoverAttachment.URLString
        
        if let realm = realm {
            let _ = try? realm.write {
                realm.add(newAttachment)
            }
        }
        
        return newAttachment
        
    }).filter({ $0 != nil }).map({ discoverAttachment in discoverAttachment! })

}

func userSkillsFromSkills(skills: [Skill], inRealm realm: Realm) -> [UserSkill] {

    return skills.map({ skill -> UserSkill? in

        let skillID = skill.id
        var userSkill = userSkillWithSkillID(skillID, inRealm: realm)

        if userSkill == nil {
            let newUserSkill = UserSkill()
            newUserSkill.skillID = skillID

            realm.add(newUserSkill)

            userSkill = newUserSkill
        }

        if let userSkill = userSkill {

            // create or update detail

            userSkill.name = skill.name
            userSkill.localName = skill.localName

            if let coverURLString = skill.coverURLString {
                userSkill.coverURLString = coverURLString
            }

            if let skillCategory = skill.category, skillCategoryID = skill.category?.id {
                var userSkillCategory = userSkillCategoryWithSkillCategoryID(skillCategoryID, inRealm: realm)

                if userSkillCategory == nil {
                    let newUserSkillCategory = UserSkillCategory()
                    newUserSkillCategory.skillCategoryID = skillCategoryID
                    newUserSkillCategory.name = skillCategory.name
                    newUserSkillCategory.localName = skillCategory.localName

                    realm.add(newUserSkillCategory)

                    userSkillCategory = newUserSkillCategory
                }

                if let userSkillCategory = userSkillCategory {
                    userSkill.category = userSkillCategory
                }
            }
        }

        return userSkill

    }).filter({ $0 != nil }).map({ skill in skill! })
}

func userSocialAccountProvidersFromSocialAccountProviders(socialAccountProviders: [DiscoveredUser.SocialAccountProvider]) -> [UserSocialAccountProvider] {
    return socialAccountProviders.map({ _provider -> UserSocialAccountProvider in
        let provider = UserSocialAccountProvider()
        provider.name = _provider.name
        provider.enabled = _provider.enabled

        return provider
    })
}

func userSkillsFromSkillsData(skillsData: [JSONDictionary], inRealm realm: Realm) -> [UserSkill] {
    var userSkills = [UserSkill]()

    for skillInfo in skillsData {
        if let
            skillID = skillInfo["id"] as? String,
            skillName = skillInfo["name"] as? String,
            skillLocalName = skillInfo["name_string"] as? String {

                var userSkill = userSkillWithSkillID(skillID, inRealm: realm)

                if userSkill == nil {
                    let newUserSkill = UserSkill()
                    newUserSkill.skillID = skillID

                    realm.add(newUserSkill)

                    userSkill = newUserSkill
                }

                if let userSkill = userSkill {

                    // create or update detail
                    
                    userSkill.name = skillName
                    userSkill.localName = skillLocalName

                    if let coverURLString = skillInfo["cover_url"] as? String {
                        userSkill.coverURLString = coverURLString
                    }

                    if let
                        categoryData = skillInfo["category"] as? JSONDictionary,
                        skillCategoryID = categoryData["id"] as? String,
                        skillCategoryName = categoryData["name"] as? String,
                        skillCategoryLocalName = categoryData["name_string"] as? String {

                            var userSkillCategory = userSkillCategoryWithSkillCategoryID(skillCategoryID, inRealm: realm)

                            if userSkillCategory == nil {
                                let newUserSkillCategory = UserSkillCategory()
                                newUserSkillCategory.skillCategoryID = skillCategoryID
                                newUserSkillCategory.name = skillCategoryName
                                newUserSkillCategory.localName = skillCategoryLocalName

                                realm.add(newUserSkillCategory)

                                userSkillCategory = newUserSkillCategory
                            }

                            if let userSkillCategory = userSkillCategory {
                                userSkill.category = userSkillCategory
                            }
                    }

                    userSkills.append(userSkill)
                }
        }
    }

    return userSkills
}

func syncMyInfoAndDoFurtherAction(furtherAction: () -> Void) {

    userInfo(failureHandler: { (reason, errorMessage) in
        defaultFailureHandler(reason, errorMessage: errorMessage)

        furtherAction()

    }, completion: { friendInfo in

        //println("my userInfo: \(friendInfo)")

        dispatch_async(realmQueue) {

            if let myUserID = YepUserDefaults.userID.value {

                guard let realm = try? Realm() else {
                    return
                }

                var me = userWithUserID(myUserID, inRealm: realm)

                if me == nil {
                    let newUser = User()
                    newUser.userID = myUserID

                    newUser.friendState = UserFriendState.Me.rawValue

                    if let createdUnixTime = friendInfo["created_at"] as? NSTimeInterval {
                        newUser.createdUnixTime = createdUnixTime
                    }

                    let _ = try? realm.write {
                        realm.add(newUser)
                    }

                    me = newUser
                }

                if let user = me {

                    // 更新用户信息

                    updateUserWithUserID(user.userID, useUserInfo: friendInfo)

                    // 更新 DoNotDisturb

                    if let
                        fromString = friendInfo["mute_started_at_string"] as? String,
                        toString = friendInfo["mute_ended_at_string"] as? String {

                            if !fromString.isEmpty && !toString.isEmpty {

                                var userDoNotDisturb = user.doNotDisturb

                                if userDoNotDisturb == nil {
                                    let _userDoNotDisturb = UserDoNotDisturb()
                                    _userDoNotDisturb.isOn = true

                                    let _ = try? realm.write {
                                        user.doNotDisturb = _userDoNotDisturb
                                    }

                                    userDoNotDisturb = _userDoNotDisturb
                                }
                                
                                if let userDoNotDisturb = userDoNotDisturb {

                                    let convert: (Int, Int) -> (Int, Int) = { serverHour, serverMinute in

                                        let localHour: Int
                                        let localMinute: Int

                                        if serverMinute + userDoNotDisturb.minuteOffset >= 60 {
                                            localHour = (serverHour + userDoNotDisturb.hourOffset + 1) % 24

                                        } else {
                                            localHour = (serverHour + userDoNotDisturb.hourOffset) % 24
                                        }

                                        localMinute = (serverMinute + userDoNotDisturb.minuteOffset) % 60

                                        return (localHour, localMinute)
                                    }

                                    let _ = try? realm.write {

                                        let fromParts = fromString.componentsSeparatedByString(":")

                                        if let
                                            fromHourString = fromParts[safe: 0], fromHour = Int(fromHourString),
                                            fromMinuteString = fromParts[safe: 1], fromMinute = Int(fromMinuteString) {

                                                (userDoNotDisturb.fromHour, userDoNotDisturb.fromMinute) = convert(fromHour, fromMinute)
                                        }

                                        let toParts = toString.componentsSeparatedByString(":")

                                        if let
                                            toHourString = toParts[safe: 0], toHour = Int(toHourString),
                                            toMinuteString = toParts[safe: 1], toMinute = Int(toMinuteString) {

                                                (userDoNotDisturb.toHour, userDoNotDisturb.toMinute) = convert(toHour, toMinute)
                                        }

                                        //println("userDoNotDisturb: \(userDoNotDisturb.isOn), from \(userDoNotDisturb.fromHour):\(userDoNotDisturb.fromMinute), to \(userDoNotDisturb.toHour):\(userDoNotDisturb.toMinute)")
                                    }
                                }

                            } else {
                                if let userDoNotDisturb = user.doNotDisturb {
                                    realm.delete(userDoNotDisturb)
                                }
                            }
                    }


                    // also save some infomation in YepUserDefaults

                    if let nickname = friendInfo["nickname"] as? String {
                        YepUserDefaults.nickname.value = nickname
                    }

                    if let introduction = friendInfo["introduction"] as? String {
                        YepUserDefaults.introduction.value = introduction
                    }

                    if let avatarURLString = friendInfo["avatar_url"] as? String {
                        YepUserDefaults.avatarURLString.value = avatarURLString
                    }

                    if let badge = friendInfo["badge"] as? String {
                        YepUserDefaults.badge.value = badge
                    }

                    if let areaCode = friendInfo["phone_code"] as? String {
                        YepUserDefaults.areaCode.value = areaCode
                    }

                    if let mobile = friendInfo["mobile"] as? String {
                        YepUserDefaults.mobile.value = mobile
                    }
                }
            }

            furtherAction()
        }
    })
}

func syncFriendshipsAndDoFurtherAction(furtherAction: () -> Void) {

    friendships { allFriendships in
        //println("\n allFriendships: \(allFriendships)")

        dispatch_async(realmQueue) {

            // 先整理出所有的 friend 的 userID
            var remoteUerIDSet = Set<String>()
            for friendshipInfo in allFriendships {
                if let friendInfo = friendshipInfo["friend"] as? JSONDictionary {
                    if let userID = friendInfo["id"] as? String {
                        remoteUerIDSet.insert(userID)
                    }
                }
            }

            // 改变没有 friendship 的 user 的状态

            guard let realm = try? Realm() else {
                return
            }

            let localUsers = realm.objects(User)

            for i in 0..<localUsers.count {
                let localUser = localUsers[i]

                if !remoteUerIDSet.contains(localUser.userID) {

                    let _ = try? realm.write {

                        localUser.friendshipID = ""

                        if let myUserID = YepUserDefaults.userID.value {
                            if myUserID == localUser.userID {
                                localUser.friendState = UserFriendState.Me.rawValue

                            } else if localUser.friendState == UserFriendState.Normal.rawValue {
                                localUser.friendState = UserFriendState.Stranger.rawValue
                            }
                        }
                        
                        localUser.isBestfriend = false
                    }
                }
            }

            // 添加有 friendship 但本地存储还没有的 user，更新信息

            for friendshipInfo in allFriendships {
                if let friendInfo = friendshipInfo["friend"] as? JSONDictionary {
                    if let userID = friendInfo["id"] as? String {
                        var user = userWithUserID(userID, inRealm: realm)

                        if user == nil {
                            let newUser = User()
                            newUser.userID = userID

                            if let createdUnixTime = friendInfo["created_at"] as? NSTimeInterval {
                                newUser.createdUnixTime = createdUnixTime
                            }

                            let _ = try? realm.write {
                                realm.add(newUser)
                            }

                            user = newUser
                        }

                        if let user = user {

                            // 更新用户信息

                            updateUserWithUserID(user.userID, useUserInfo: friendInfo)

                            let _ = try? realm.write {

                                if let friendshipID = friendshipInfo["id"] as? String {
                                    user.friendshipID = friendshipID
                                }

                                user.friendState = UserFriendState.Normal.rawValue

                                if let isBestfriend = friendInfo["favored"] as? Bool {
                                    user.isBestfriend = isBestfriend
                                }
                                
                                if let bestfriendIndex = friendInfo["favored_position"] as? Int {
                                    user.bestfriendIndex = bestfriendIndex
                                }
                            }
                        }
                    }
                }
            }
            
            // do further action

            furtherAction()
        }
    }
}

func syncGroupsAndDoFurtherAction(furtherAction: () -> Void) {

    groups { allGroups in
        //println("allGroups: \(allGroups)")

        dispatch_async(realmQueue) {

            // 先整理出所有的 group 的 groupID

            var remoteGroupIDSet = Set<String>()
            for groupInfo in allGroups {
                if let groupID = groupInfo["id"] as? String {
                    remoteGroupIDSet.insert(groupID)
                }
            }

            // 再在本地去除远端没有的 Group

            guard let realm = try? Realm() else {
                return
            }

            let localGroups = realm.objects(Group)

            let _ = try? realm.write {

                var groupsToDelete = [Group]()
                for i in 0..<localGroups.count {
                    let localGroup = localGroups[i]

                    if !remoteGroupIDSet.contains(localGroup.groupID) {
                        groupsToDelete.append(localGroup)
                    }
                }
                for group in groupsToDelete {
                    realm.delete(group)
                    // TODO: 级联删除关联的数据对象
                }
            }

            // 增加本地没有的 Group

            for groupInfo in allGroups {

                let group = syncGroupWithGroupInfo(groupInfo, inRealm: realm)

                //Sync Feed

                if let
                    topic = groupInfo["topic"] as? JSONDictionary,
                    feedData = DiscoveredFeed.fromJSONDictionary(topic),
                    group = group {
                        saveFeedWithFeedDataWithFullGroup(feedData, group: group, inRealm: realm)
                }
            }
            
            // do further action
            
            furtherAction()
        }
    }
}

func syncGroupWithGroupInfo(groupInfo: JSONDictionary, inRealm realm: Realm) -> Group? {

    if let groupID = groupInfo["id"] as? String {
        
        var group = groupWithGroupID(groupID, inRealm: realm)

        if group == nil {
            let newGroup = Group()
            newGroup.groupID = groupID
            if let groupName = groupInfo["name"] as? String {
                newGroup.groupName = groupName
            }

            let _ = try? realm.write {
                realm.add(newGroup)
            }

            group = newGroup
        }

        if let group = group {

            if group.conversation == nil {
                let conversation = Conversation()
                conversation.type = ConversationType.Group.rawValue
                conversation.withGroup = group

                let _ = try? realm.write {
                    realm.add(conversation)
                }
            }

            // Group Owner

            if let ownerInfo = groupInfo["owner"] as? JSONDictionary {
                if let ownerID = ownerInfo["id"] as? String {
                    var owner = userWithUserID(ownerID, inRealm: realm)

                    if owner == nil {
                        let newUser = User()

                        newUser.userID = ownerID

                        if let createdUnixTime = ownerInfo["created_at"] as? NSTimeInterval {
                            newUser.createdUnixTime = createdUnixTime
                        }

                        if let myUserID = YepUserDefaults.userID.value {
                            if myUserID == ownerID {
                                newUser.friendState = UserFriendState.Me.rawValue
                            } else {
                                newUser.friendState = UserFriendState.Stranger.rawValue
                            }
                        } else {
                            newUser.friendState = UserFriendState.Stranger.rawValue
                        }

                        let _ = try? realm.write {
                            realm.add(newUser)
                        }

                        owner = newUser
                    }
                    
                    if let owner = owner {

                        // 更新个人信息

                        updateUserWithUserID(owner.userID, useUserInfo: ownerInfo)

                        let _ = try? realm.write {
                            group.owner = owner
                        }
                    }
                }
            }

            // 同步 Group 的成员

            if let remoteMembers = groupInfo["members"] as? [JSONDictionary] {
                var memberIDSet = Set<String>()
                for memberInfo in remoteMembers {
                    if let memberID = memberInfo["id"] as? String {
                        memberIDSet.insert(memberID)
                    }
                }

                let localMembers = group.members

                // 去除远端没有的 member

                for (index, member) in localMembers.enumerate() {
                    let user = member
                    if !memberIDSet.contains(user.userID) {
                        localMembers.removeAtIndex(index)
                    }
                }

                // 加上本地没有的 member

                for memberInfo in remoteMembers {

                    if let memberID = memberInfo["id"] as? String {

                        var member = userWithUserID(memberID, inRealm: realm)

                        if member == nil {
                            let newMember = User()

                            newMember.userID = memberID

                            if let createdUnixTime = memberInfo["created_at"] as? NSTimeInterval {
                                newMember.createdUnixTime = createdUnixTime
                            }

                            if let myUserID = YepUserDefaults.userID.value {
                                if myUserID == memberID {
                                    newMember.friendState = UserFriendState.Me.rawValue
                                } else {
                                    newMember.friendState = UserFriendState.Stranger.rawValue
                                }
                            } else {
                                newMember.friendState = UserFriendState.Stranger.rawValue
                            }

                            let _ = try? realm.write {
                                realm.add(newMember)

                                localMembers.append(newMember)
                            }

                            member = newMember
                        }

                        if let member = member {

                            // 更新个人信息

                            updateUserWithUserID(member.userID, useUserInfo: memberInfo)
                        }
                    }
                }

                let _ = try? realm.write {
                    group.members.removeAll()
                    group.members.appendContentsOf(localMembers)
                }
            }
        }

        return group
    }

    return nil
}

var isFetchingUnreadMessages = Listenable<Bool>(false) { _ in }

func syncUnreadMessagesAndDoFurtherAction(furtherAction: (messageIDs: [String]) -> Void) {

    dispatch_async(dispatch_get_main_queue()) {
        isFetchingUnreadMessages.value = true
    }

    unreadMessages { allUnreadMessages in

        //println("\n allUnreadMessages: \(allUnreadMessages)")
        println("Got unread message: \(allUnreadMessages.count)")
        
        dispatch_async(dispatch_get_main_queue()) {

            guard let realm = try? Realm() else {
                return
            }

            var messageIDs = [String]()

            for messageInfo in allUnreadMessages {
                syncMessageWithMessageInfo(messageInfo, messageAge: .New, inRealm: realm) { _messageIDs in
                    messageIDs += _messageIDs
                }
            }

            // do futher action
            furtherAction(messageIDs: messageIDs)

            isFetchingUnreadMessages.value = false
        }
    }
}

func syncMessagesReadStatus() {
    
    sentButUnreadMessages(failureHandler: { (reason, message) -> Void in
        
    }, completion: { messagesDictionary in
      
        if let messageIDs = messagesDictionary["message_ids"] as? [String] {
            guard let realm = try? Realm() else {
                return
            }
            var messages = messagesUnreadSentByMe(inRealm: realm)
            
            var toMarkMessages = [Message]()
            
            if messageIDs.count < 1 {
                for oldMessage in messages {
                    if oldMessage.sendState == MessageSendState.Successed.rawValue {
                        toMarkMessages.append(oldMessage)
                    }
                }
            } else {
                for messageID in messageIDs {
                    let predicate = NSPredicate(format: "messageID != %@", argumentArray: [messageID])
                    messages = messages.filter(predicate)
                }
                
                for message in messages {
                    toMarkMessages.append(message)
                }
            }
            
            let _ = try? realm.write {
                for message in toMarkMessages {
                    message.sendState = MessageSendState.Read.rawValue
                    message.readed = true
                }
            }
        }
    })
}

func recordMessageWithMessageID(messageID: String, detailInfo messageInfo: JSONDictionary, inRealm realm: Realm) {

    if let message = messageWithMessageID(messageID, inRealm: realm) {

        let _ = try? realm.write {

            if let user = message.fromFriend where user.userID == YepUserDefaults.userID.value {
                message.sendState = MessageSendState.Read.rawValue
            }

            if let textContent = messageInfo["text_content"] as? String {
                message.textContent = textContent
            }

            if let
                longitude = messageInfo["longitude"] as? Double,
                latitude = messageInfo["latitude"] as? Double {

                    let coordinate = Coordinate()
                    coordinate.safeConfigureWithLatitude(latitude, longitude: longitude)
                    
                    message.coordinate = coordinate
            }

            if let attachments = messageInfo["attachments"] as? [JSONDictionary] {

                for attachmentInfo in attachments {

                    // S3: normal file
                    if let
                        normalFileInfo = attachmentInfo["file"] as? JSONDictionary,
                        fileURLString = normalFileInfo["url"] as? String,
                        kind = attachmentInfo["kind"] as? String {
                            if kind == "thumbnail" {
                                message.thumbnailURLString = fileURLString
                            } else {
                                message.attachmentURLString = fileURLString
                            }
                    }

                    if let metaDataString = attachmentInfo["metadata"] as? String {
                        message.mediaMetaData = mediaMetaDataFromString(metaDataString, inRealm: realm)
                    }
                }

                if let mediaType = messageInfo["media_type"] as? String {

                    switch mediaType {
                    case MessageMediaType.Text.description:
                        message.mediaType = MessageMediaType.Text.rawValue
                    case MessageMediaType.Image.description:
                        message.mediaType = MessageMediaType.Image.rawValue
                    case MessageMediaType.Video.description:
                        message.mediaType = MessageMediaType.Video.rawValue
                    case MessageMediaType.Audio.description:
                        message.mediaType = MessageMediaType.Audio.rawValue
                    case MessageMediaType.Sticker.description:
                        message.mediaType = MessageMediaType.Sticker.rawValue
                    case MessageMediaType.Location.description:
                        message.mediaType = MessageMediaType.Location.rawValue
                    default:
                        break
                    }
                    // TODO: 若有更多的 Media Type
                }
            }
        }
    }
}

func syncMessageWithMessageInfo(messageInfo: JSONDictionary, messageAge: MessageAge, inRealm realm: Realm, andDoFurtherAction furtherAction: ((messageIDs: [String]) -> Void)? ) {

    func deleteMessage(message: Message, inRealm realm: Realm) {
        let _ = try? realm.write {
            realm.delete(message)
        }
    }

    if let messageID = messageInfo["id"] as? String {

        var message = messageWithMessageID(messageID, inRealm: realm)

        if message == nil {
            let newMessage = Message()
            newMessage.messageID = messageID

            if let updatedUnixTime = messageInfo["created_at"] as? NSTimeInterval {
                newMessage.createdUnixTime = updatedUnixTime
            }

            if case .New = messageAge {
                // 确保网络来的新消息比任何已有的消息都要新，防止服务器消息延后发来导致插入到当前消息上面
                if let latestMessage = realm.objects(Message).sorted("createdUnixTime", ascending: true).last {
                    if newMessage.createdUnixTime < latestMessage.createdUnixTime {
                        println("before newMessage.createdUnixTime: \(newMessage.createdUnixTime)")
                        newMessage.createdUnixTime = latestMessage.createdUnixTime + YepConfig.Message.localNewerTimeInterval
                        println("adjust newMessage.createdUnixTime: \(newMessage.createdUnixTime)")
                    }
                }
            }

            let _ = try? realm.write {
                realm.add(newMessage)
            }

            message = newMessage
        }

        // 开始填充消息

        if let message = message {

            // 原本是判断标记失败时再次标记，现已改为 batch 标记，先注释了
            /*
            if message.readed == true {
                markAsReadMessage(message, failureHandler: nil) { success in
                    if success {
                        println("Mark message \(messageID) as read")
                    }
                }
            }
            */

            // 纪录消息的发送者

            if let senderInfo = messageInfo["sender"] as? JSONDictionary {
                if let senderID = senderInfo["id"] as? String {
                    var sender = userWithUserID(senderID, inRealm: realm)
                    
                    if sender == nil {
                        let newUser = User()

                        newUser.userID = senderID

                        newUser.friendState = UserFriendState.Stranger.rawValue

                        let _ = try? realm.write {
                            realm.add(newUser)
                        }

                        sender = newUser
                    }

                    if let sender = sender {

                        updateUserWithUserID(sender.userID, useUserInfo: senderInfo)

                        let _ = try? realm.write {
                            message.fromFriend = sender
                        }

                        // 查询消息来自的 Group，为空就表示来自 User

                        var sendFromGroup: Group? = nil

                        if let recipientType = messageInfo["recipient_type"] as? String {
                            if recipientType == "Circle" {
                                if let groupID = messageInfo["recipient_id"] as? String {
                                    sendFromGroup = groupWithGroupID(groupID, inRealm: realm)

                                    if sendFromGroup == nil {
                                        let newGroup = Group()
                                        newGroup.groupID = groupID

                                        if let groupInfo = messageInfo["circle"] as? JSONDictionary {
                                            if let groupName = groupInfo["name"] as? String {
                                                newGroup.groupName = groupName
                                            }
                                        }

                                        let _ = try? realm.write {
                                            realm.add(newGroup)
                                        }

                                        sendFromGroup = newGroup
                                    }
                                }
                            }
                        }

                        // 纪录消息所属的 Conversation

                        var conversation: Conversation?

                        var conversationWithUser: User? // 注意：对于自己发送的消息被自己同步，要以其接收者来建立 Conversation

                        if let sendFromGroup = sendFromGroup {
                            conversation = sendFromGroup.conversation

                        } else {
                            if sender.userID != YepUserDefaults.userID.value {
                                conversation = sender.conversation
                                conversationWithUser = sender

                            } else {
                                if let userID = messageInfo["recipient_id"] as? String, user = userWithUserID(userID, inRealm: realm) {
                                    conversation = user.conversation
                                    conversationWithUser = user
                                }
                            }
                        }

                        // 没有 Conversation 就尝试建立它

                        if conversation == nil {
                            let newConversation = Conversation()

                            if let sendFromGroup = sendFromGroup {
                                newConversation.type = ConversationType.Group.rawValue
                                newConversation.withGroup = sendFromGroup
                            } else {
                                newConversation.type = ConversationType.OneToOne.rawValue
                                newConversation.withFriend = conversationWithUser
                            }

                            let _ = try? realm.write {
                                realm.add(newConversation)
                            }

                            conversation = newConversation
                        }

                        // 在保证有 Conversation 的情况下继续，不然消息没有必要保留

                        if let conversation = conversation {

                            var sectionDateMessageID: String?

                            let _ = try? realm.write {

                                conversation.updatedUnixTime = message.createdUnixTime

                                message.conversation = conversation

                                tryCreateSectionDateMessageInConversation(conversation, beforeMessage: message, inRealm: realm) { sectionDateMessage in
                                    realm.add(sectionDateMessage)
                                    sectionDateMessageID = sectionDateMessage.messageID
                                }
                            }

                            // 纪录消息的 detail 信息

                            recordMessageWithMessageID(messageID, detailInfo: messageInfo, inRealm: realm)

                            // Do furtherAction after sync

                            if let sectionDateMessageID = sectionDateMessageID {
                                furtherAction?(messageIDs: [sectionDateMessageID, messageID])
                            } else {
                                furtherAction?(messageIDs: [messageID])
                            }

                        } else {
                            deleteMessage(message, inRealm: realm)
                        }
                    }
                }
            }
        }
    }
}

