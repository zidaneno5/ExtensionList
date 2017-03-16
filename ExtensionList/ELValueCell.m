//
//  ELValueCell.m
//  ExtensionList
//
//  Created by duyongchao on 2017/3/14.
//
//

#import "ELValueCell.h"

@implementation ELValueCell

@synthesize delegate;

- (void)loadValue:(id)value
{
}

- (void)loadValue:(id)value withTitle:(NSString *)title
{
    [self loadValue:value];
}

- (void)didSelect
{
}

@end

@implementation ELSwitchCell

@synthesize switchView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
        [switchView addTarget:self action:@selector(valueChanged) forControlEvents:UIControlEventValueChanged];
        [self setAccessoryView:switchView];
    }
    return self;
}

- (void)dealloc
{
    [switchView release];
    [super dealloc];
}

- (void)loadValue:(id)value
{
    switchView.on = [value boolValue];
}

- (void)valueChanged
{
    id value = [NSNumber numberWithBool:switchView.on];
    [[self delegate] valueCell:self didChangeToValue:value];
}

@end

@implementation ELCheckCell

- (void)loadValue:(id)value
{
    [self setAccessoryType:[value boolValue] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];
}

- (void)didSelect
{
    UITableViewCellAccessoryType type = [self accessoryType];
    [self setAccessoryType:(type == UITableViewCellAccessoryNone) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];
    id value = [NSNumber numberWithBool:type == UITableViewCellAccessoryNone];
    [[self delegate] valueCell:self didChangeToValue:value];
}

@end

@implementation ELDisclosureIndicatedCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier])) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)loadValue:(id)value withTitle:(NSString *)title
{
    self.detailTextLabel.text = title ?: [value description];
}

@end
