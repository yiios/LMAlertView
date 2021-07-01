//
//  YIAlertView.m
//  YIAlertView
//
//  Created by YiiOS on 07/01/2021.
//  Copyright (c) 2021 YiiOS. All rights reserved.
//

#import "YIAlertView.h"
#import <UIKit/UIAlertController.h>

@interface YIAlertView ()

@property (strong, nonatomic) UIAlertController *alertController;

@property (nullable,nonatomic,copy) NSString *cancelButtonTitle;
@property (nullable,nonatomic,strong) NSMutableArray <NSString *>*buttonTitleArray;

@property (nullable,nonatomic,strong) NSMutableArray <UITextField *>*textFieldArray;

@property (strong, nonatomic) UIWindow *previousWindow;
@property (strong, nonatomic) UIWindow *alertWindow;

@property (nonatomic,assign) NSInteger firstOtherButtonIndex;    // -1 if no otherButtonTitles or initWithTitle:... not used
@property (nonatomic,assign,getter=isVisible) BOOL visible;

@end

@implementation YIAlertView

#pragma mark - Life

- (instancetype)init {
    if (self = [self initWithTitle:nil message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:nil]) {
    }
   return self;
}

- (instancetype)initWithTitle:(nullable NSString *)title message:(nullable NSString *)message delegate:(nullable id /*<YIAlertViewDelegate>*/)delegate cancelButtonTitle:(nullable NSString *)cancelButtonTitle otherButtonTitles:(nullable NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION  {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    if (self = [super init]) {
        
        // index 初始化
        self.firstOtherButtonIndex = -1;
        self.cancelButtonIndex = -1;
        
        // 入参赋值
        self.title = title;
        self.message = message;
        self.delegate = delegate;
        self.cancelButtonTitle = cancelButtonTitle;
                
        // 按键组拼合
        NSMutableArray *buttonTitleArray = [NSMutableArray array];
        
        // 先存取消按钮
        if (cancelButtonTitle) {
            [buttonTitleArray addObject:cancelButtonTitle];
        }
        
        if (otherButtonTitles) {
            [buttonTitleArray addObject:otherButtonTitles];
        }
        
        // 取多个入参
        va_list argumentList;
        NSString *eachStr;
        if (otherButtonTitles) {
            [buttonTitleArray addObject: otherButtonTitles];
            va_start(argumentList, otherButtonTitles);
            while((eachStr = va_arg(argumentList, NSString *))) {
                [buttonTitleArray addObject: eachStr];
            }
            va_end(argumentList);
        }
        
        self.buttonTitleArray = buttonTitleArray;
        
        // index 值计算
        NSInteger index = 0;
        for (NSString *buttonStr in self.buttonTitleArray) {
            
            if (self.cancelButtonTitle == buttonStr && self.cancelButtonIndex == -1) {
                self.cancelButtonIndex = index;
            } else if (self.firstOtherButtonIndex == -1) {
                self.firstOtherButtonIndex = index;
            }
            
            index++;
        }
        
        // 配置 window
        [self setupNewWindow];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    
    if (self = [super init]) {
    }
    
    return self;
}
- (nullable instancetype) initWithCoder:(NSCoder *)coder  {
    if (self = [super init]) {
    }
    
    return self;
}

#pragma mark - Public

- (NSInteger)addButtonWithTitle:(nullable NSString *)title {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    
    [self.buttonTitleArray addObject:title];
    
    // alertController 如果已经创建出来了 那么需要后面追加按钮
    if (self.alertController) {
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSInteger index = [self.alertController.actions indexOfObject:action];
            [self dismissWithClickedButtonIndex:index animated:YES];
        }];
        [self.alertController addAction:defaultAction];
    }
    
    return [self.buttonTitleArray indexOfObject:title];
}

- (nullable NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex {
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    return [self.buttonTitleArray objectAtIndex:buttonIndex];
}

- (NSInteger)numberOfButtons {
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    return self.buttonTitleArray.count;
}

- (void)setCancelButtonIndex:(NSInteger)cancelButtonIndex {
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    _cancelButtonIndex =cancelButtonIndex;
}

// shows popup alert animated.
- (void)show {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self show];
        });
        return;
    }

    [self setupAlertController];
    
    // Add window subview
//    [_alertWindow.rootViewController addChildViewController:self.alertController];
//    [_alertWindow.rootViewController.view addSubview:self.alertController.view];
//    self.alertController.view.center = _alertWindow.rootViewController.view.center;

    [self.alertWindow makeKeyAndVisible];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(willPresentAlertView:)]) {
        [self.delegate willPresentAlertView:self];
    }
    
    [self.alertWindow.rootViewController presentViewController:self.alertController animated:YES completion:^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(didPresentAlertView:)]) {
            [self.delegate didPresentAlertView:self];
        }
    }];


//    _alertWindow.rootViewController.view.alpha = 0.0f;
//
//    [UIView animateWithDuration:0.2 animations:^{
//        self->_alertWindow.rootViewController.view.alpha = 1.0f;
//    } completion:^(BOOL finished) {
//        self->_visible = YES;
//        if (self.delegate && [self.delegate respondsToSelector:@selector(didPresentAlertView:)]) {
//            [self.delegate didPresentAlertView:self];
//        }
//    }];

}

// hides alert sheet or popup. use this method when you need to explicitly dismiss the alert.
// it does not need to be called if the user presses on a button
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissWithClickedButtonIndex:buttonIndex animated:animated];
        });
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        [self.delegate alertView:self clickedButtonAtIndex:buttonIndex];
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(alertView:willDismissWithButtonIndex:)]) {
        [self.delegate alertView:self willDismissWithButtonIndex:buttonIndex];
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        self.alertWindow.rootViewController.view.alpha = 1.0f;
    } completion:^(BOOL finished) {
        self.visible = NO;
        if (self.delegate && [self.delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)]) {
            [self.delegate alertView:self didDismissWithButtonIndex:buttonIndex];
        }
    }];

    // Restore previous window
    [self.previousWindow makeKeyAndVisible];
    self.previousWindow = nil;
    
    [self.alertWindow resignKeyWindow];
    self.alertWindow.hidden=YES;
}

// Retrieve a text field at an index
// The field at index 0 will be the first text field (the single field or the login field), the field at index 1 will be the password field. */
- (nullable UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex API_AVAILABLE(ios(5.0)) {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    if (!self.alertController) {
        [self setupAlertController];
    }
    
    return [self.textFieldArray objectAtIndex:textFieldIndex];
}

#pragma mark - Private

- (void)setupAlertController {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupAlertController];
        });
        return;
    }
    
    if (self.alertController) {
        return;
    }
    
    self.alertController = [UIAlertController alertControllerWithTitle:self.title message:self.message preferredStyle:UIAlertControllerStyleAlert];
        
    [self.alertController setTitle:self.message];
        
    for (NSString *buttonStr in self.buttonTitleArray) {
        
        if (self.cancelButtonTitle == buttonStr) {
            // cancel 按钮
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:self.cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                NSInteger index = [self.alertController.actions indexOfObject:action];
                [self dismissWithClickedButtonIndex:index animated:YES];
            }];
            [self.alertController addAction:cancelAction];
            continue;
        }
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:buttonStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSInteger index = [self.alertController.actions indexOfObject:action];
            [self dismissWithClickedButtonIndex:index animated:YES];
        }];
        [self.alertController addAction:defaultAction];
    }
    

    switch (self.alertViewStyle) {
        case UIAlertViewStyleDefault: {
            break;
        }
        case UIAlertViewStyleSecureTextInput: {
            [self.textFieldArray removeAllObjects];
            
            __weak typeof(self)weakSelf = self;
            [self.alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                __strong typeof(weakSelf)strongSelf = weakSelf;
                textField.secureTextEntry = YES;
                [strongSelf.textFieldArray addObject:textField];
            }];
            break;
        }
        case UIAlertViewStylePlainTextInput: {
            [self.textFieldArray removeAllObjects];
            
            __weak typeof(self)weakSelf = self;
            [self.alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                __strong typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf.textFieldArray addObject:textField];
            }];
            break;
        }
        case UIAlertViewStyleLoginAndPasswordInput: {
            [self.textFieldArray removeAllObjects];
            
            __weak typeof(self)weakSelf = self;
            [self.alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                __strong typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf.textFieldArray addObject:textField];
            }];
            [self.alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                __strong typeof(weakSelf)strongSelf = weakSelf;
                textField.secureTextEntry = YES;
                [strongSelf.textFieldArray addObject:textField];
            }];
            break;
        }
        default:
            break;
    }
    
}


- (void)setupNewWindow {
    
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");
    // 配置 window
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupNewWindow];
        });
        return;
    }

    // Save previous window
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene.delegate conformsToProtocol:@protocol(UIWindowSceneDelegate)]) {
                self.previousWindow = [(id<UIWindowSceneDelegate>)scene.delegate window];
                break;
            }
        }
    } else {
        self.previousWindow = [UIApplication sharedApplication].keyWindow;
    }

    
    // Create a new one to show the alert
    UIWindow *alertWindow;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = scene;
                break;
            }
        }
        alertWindow = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)windowScene];
        alertWindow.frame = [self mainScreenFrame];
    } else {
        alertWindow = [[UIWindow alloc] initWithFrame:[self mainScreenFrame]];
    }
    
    alertWindow.windowLevel = UIWindowLevelAlert;
    alertWindow.backgroundColor = [UIColor clearColor];
    alertWindow.rootViewController = [UIViewController new];
    alertWindow.accessibilityViewIsModal = YES;
    self.alertWindow = alertWindow;
}

- (CGRect)mainScreenFrame {
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    return [UIApplication sharedApplication].keyWindow.bounds;
}


- (NSMutableArray<UITextField *> *)textFieldArray {
    NSAssert([NSThread isMainThread], @"不要在子线程操作UI");

    if (!_textFieldArray) {
        _textFieldArray = @[].mutableCopy;
    }
    return _textFieldArray;
}

#pragma mark - Runtime Injection

__asm(
      ".section        __DATA,__objc_classrefs,regular,no_dead_strip\n"
#if    TARGET_RT_64_BIT
      ".align          3\n"
      "L_OBJC_CLASS_UIAlertView:\n"
      ".quad           _OBJC_CLASS_$_UIAlertView\n"
#else
      ".align          2\n"
      "_OBJC_CLASS_UIAlertView:\n"
      ".long           _OBJC_CLASS_$_UIAlertView\n"
#endif
      ".weak_reference _OBJC_CLASS_$_UIAlertView\n"
      );

__attribute__((constructor)) static void YIAlertViewPatchEntry(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {

            Class *AlertViewClassLocation = NULL;

#if TARGET_CPU_ARM
            __asm("movw %0, :lower16:(_OBJC_CLASS_UIAlertView-(LPC0+4))\n"
                  "movt %0, :upper16:(_OBJC_CLASS_UIAlertView-(LPC0+4))\n"
                  "LPC0: add %0, pc" : "=r"(AlertViewClassLocation));
#elif TARGET_CPU_ARM64
            __asm("adrp %0, L_OBJC_CLASS_UIAlertView@PAGE\n"
                  "add  %0, %0, L_OBJC_CLASS_UIAlertView@PAGEOFF" : "=r"(AlertViewClassLocation));
#elif TARGET_CPU_X86_64
            __asm("leaq L_OBJC_CLASS_UIAlertView(%%rip), %0" : "=r"(AlertViewClassLocation));
#elif TARGET_CPU_X86
            void *pc = NULL;
            __asm("calll L0\n"
                  "L0: popl %0\n"
                  "leal _OBJC_CLASS_UIAlertView-L0(%0), %1" : "=r"(pc), "=r"(AlertViewClassLocation));
#else
#error Unsupported CPU
#endif

            if (AlertViewClassLocation) {
                *AlertViewClassLocation = YIAlertView.class;
            }
        }
    });
}


@end
