//
//  TCWeiboModel.m
//  ModelBenchmark
//
//  Created by cdk on 15/10/27.
//  Copyright © 2015年 ibireme. All rights reserved.
//

#import "TCWeiboModel.h"
#import "NSObject+TCNSCoding.h"

@implementation TCWeiboPictureMetadata

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [TCMappingOption optionWithNameMapping:@{@"cutType" : @"cut_type"}];
    }
    
    return opt;
}


- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (id)copyWithZone:(NSZone *)zone { return [self tc_copy]; }

@end

@implementation TCWeiboPicture

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [TCMappingOption optionWithNameMapping:@{@"picID" : @"pic_id",
                                                       @"keepSize" : @"keep_size",
                                                       @"photoTag" : @"photo_tag",
                                                       @"objectID" : @"object_id",
                                                       @"middlePlus" : @"middleplus"}];
    }
    
    return opt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (id)copyWithZone:(NSZone *)zone { return [self tc_copy]; }

@end

@implementation TCWeiboURL

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [TCMappingOption optionWithNameMapping:@{@"oriURL" : @"ori_url",
                                                       @"urlTitle" : @"url_title",
                                                       @"urlTypePic" : @"url_type_pic",
                                                       @"urlType" : @"url_type",
                                                       @"shortURL" : @"short_url",
                                                       @"actionLog" : @"actionlog",
                                                       @"pageID" : @"page_id",
                                                       @"storageType" : @"storage_type"}];
    }
    
    return opt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (id)copyWithZone:(NSZone *)zone { return [self tc_copy]; }

@end

@implementation TCWeiboUser

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [TCMappingOption optionWithNameMapping:@{@"userID" : @"id",
                                                       @"idString" : @"idstr",
                                                       @"genderString" : @"gender",
                                                       @"biFollowersCount" : @"bi_followers_count",
                                                       @"profileImageURL" : @"profile_image_url",
                                                       @"uclass" : @"class",
                                                       @"verifiedContactEmail" : @"verified_contact_email",
                                                       @"statusesCount" : @"statuses_count",
                                                       @"geoEnabled" : @"geo_enabled",
                                                       @"followMe" : @"follow_me",
                                                       @"coverImagePhone" : @"cover_image_phone",
                                                       @"desc" : @"description",
                                                       @"followersCount" : @"followers_count",
                                                       @"verifiedContactMobile" : @"verified_contact_mobile",
                                                       @"avatarLarge" : @"avatar_large",
                                                       @"verifiedTrade" : @"verified_trade",
                                                       @"profileURL" : @"profile_url",
                                                       @"coverImage" : @"cover_image",
                                                       @"onlineStatus"  : @"online_status",
                                                       @"badgeTop" : @"badge_top",
                                                       @"verifiedContactName" : @"verified_contact_name",
                                                       @"screenName" : @"screen_name",
                                                       @"verifiedSourceURL" : @"verified_source_url",
                                                       @"pagefriendsCount" : @"pagefriends_count",
                                                       @"verifiedReason" : @"verified_reason",
                                                       @"friendsCount" : @"friends_count",
                                                       @"blockApp" : @"block_app",
                                                       @"hasAbilityTag" : @"has_ability_tag",
                                                       @"avatarHD" : @"avatar_hd",
                                                       @"creditScore" : @"credit_score",
                                                       @"createdAt" : @"created_at",
                                                       @"blockWord" : @"block_word",
                                                       @"allowAllActMsg" : @"allow_all_act_msg",
                                                       @"verifiedState" : @"verified_state",
                                                       @"verifiedReasonModified" : @"verified_reason_modified",
                                                       @"allowAllComment" : @"allow_all_comment",
                                                       @"verifiedLevel" : @"verified_level",
                                                       @"verifiedReasonURL" : @"verified_reason_url",
                                                       @"favouritesCount" : @"favourites_count",
                                                       @"verifiedType" : @"verified_type",
                                                       @"verifiedSource" : @"verified_source",
                                                       @"userAbility" : @"user_ability"}];
    }
    
    return opt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (id)copyWithZone:(NSZone *)zone { return [self tc_copy]; }

@end

@implementation TCWeiboStatus

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [TCMappingOption optionWithNameMapping:@{@"statusID" : @"id",
                                                       @"createdAt" : @"created_at",
                                                       @"attitudesStatus" : @"attitudes_status",
                                                       @"inReplyToScreenName" : @"in_reply_to_screen_name",
                                                       @"sourceType" : @"source_type",
                                                       @"commentsCount" : @"comments_count",
                                                       @"recomState" : @"recom_state",
                                                       @"urlStruct" : @"url_struct",
                                                       @"sourceAllowClick" : @"source_allowclick",
                                                       @"bizFeature" : @"biz_feature",
                                                       @"mblogTypeName" : @"mblogtypename",
                                                       @"mblogType" : @"mblogtype",
                                                       @"inReplyToStatusId" : @"in_reply_to_status_id",
                                                       @"picIds" : @"pic_ids",
                                                       @"repostsCount" : @"reposts_count",
                                                       @"attitudesCount" : @"attitudes_count",
                                                       @"darwinTags" : @"darwin_tags",
                                                       @"userType" : @"userType",
                                                       @"picInfos" : @"pic_infos",
                                                       @"inReplyToUserId" : @"in_reply_to_user_id"}];
        
        opt.typeMapping = @{@"picIds" : [NSString class],
                            @"picInfos" : [TCWeiboPicture class],
                            @"urlStruct" : [TCWeiboURL class]};
    }
    
    return opt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (id)copyWithZone:(NSZone *)zone { return [self tc_copy]; }

@end
