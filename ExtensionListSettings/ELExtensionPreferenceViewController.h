//
//  ExtensionListSettingsController.h
//  ExtensionListSettings
//
//  Created by duyongchao on 2017/3/13.
//  Copyright (c) 2017年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import "ELExtensionTableDataSource.h"
#import "ELValueCell.h"

@interface PSSpecifier (iOS5)
@property (retain, nonatomic) NSString *identifier;
@end

@interface PSListController (iOS4)
- (PSViewController *)controllerForSpecifier:(PSSpecifier *)specifier;
@end

@class ELPreferencesTableDataSource;

@interface ELExtensionPreferenceViewController : PSListController {
@private
    ELPreferencesTableDataSource *_dataSource;
    UITableView *_tableView;
    NSString *_navigationTitle;
    NSArray *descriptors;
    id settingsDefaultValue;
    NSString *settingsPath;
    NSString *preferencesKey;
    NSMutableDictionary *settings;
    NSString *settingsKeyPrefix;
    NSString *settingsChangeNotification;
    BOOL singleEnabledMode;
}

- (id)initForContentSize:(CGSize)size;

@property (nonatomic, retain) NSString *navigationTitle;
//@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, readonly) ELExtensionTableDataSource *dataSource;

- (void)cellAtIndexPath:(NSIndexPath *)indexPath didChangeToValue:(id)newValue;
- (id)valueForCellAtIndexPath:(NSIndexPath *)indexPath;
- (id)valueTitleForCellAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface ELPreferencesTableDataSource : ELExtensionTableDataSource<ELValueCellDelegate, UITableViewDelegate> {
@private
    ELExtensionPreferenceViewController *_controller;
}

- (id)initWithController:(ELExtensionPreferenceViewController *)controller;

@end
