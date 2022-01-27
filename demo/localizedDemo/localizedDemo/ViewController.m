//
//  ViewController.m
//  localizedDemo
//
//  Created by 陈谦 on 2022/1/27.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UILabel *label = [[UILabel alloc] init];
    label.textColor = UIColor.blackColor;
    label.font = [UIFont systemFontOfSize:18];
    label.frame = CGRectMake(20, 100, 200, 80);
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [self localizeString:@"networkError"];
    [self.view addSubview:label];
}

- (NSString *)localizeString:(NSString *)key {
    NSString *lang = @"en";
    NSString *path = [[NSBundle mainBundle] pathForResource:lang ofType:@"lproj"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:path];
    NSString *ret = [resourceBundle localizedStringForKey:key value:@"" table:@"CommonText"];
    return ret;
}

@end
