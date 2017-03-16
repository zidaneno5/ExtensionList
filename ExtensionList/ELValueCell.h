//
//  ELValueCell.h
//  ExtensionList
//
//  Created by duyongchao on 2017/3/14.
//
//

#import <UIKit/UIKit.h>

@protocol ELValueCellDelegate;

@interface ELValueCell : UITableViewCell {
@private
    id<ELValueCellDelegate> delegate;
}

@property (nonatomic, assign) id<ELValueCellDelegate> delegate;

- (void)loadValue:(id)value; // Deprecated
- (void)loadValue:(id)value withTitle:(NSString *)title;
- (void)didSelect;

@end

@protocol ELValueCellDelegate <NSObject>
@required
- (void)valueCell:(ELValueCell *)valueCell didChangeToValue:(id)newValue;
@end

@interface ELSwitchCell : ELValueCell {
@private
    UISwitch *switchView;
}

@property (nonatomic, readonly) UISwitch *switchView;

@end

@interface ELCheckCell : ELValueCell

@end

@interface ELDisclosureIndicatedCell : ELValueCell

@end
