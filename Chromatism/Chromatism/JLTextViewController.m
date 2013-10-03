//
//  JLTextViewController.m
//  iGitpad
//
//  Created by Johannes Lund on 2013-06-13.
//  Copyright (c) 2013 Anviking. All rights reserved.
//

#import "JLTextViewController.h"
#import "JLTokenizer.h"
#import "JLTokenizer.h"
#import "JLTextView.h"

@interface JLTextViewController ()
/// Only set from -initWithText: and directly set to nil in -loadView
@property (nonatomic, strong) NSString *defaultText;
@end

@implementation JLTextViewController

- (instancetype)initWithText:(NSString *)text
{
    self = [super init];
    if (self) {
        _defaultText = text;
    }
    return self;
}

- (void)loadView
{
    self.view = self.textView;
}

- (JLTextView *)textView
{
    if (!_textView) {
        JLTextView *textView = [[JLTextView alloc] initWithFrame:CGRectZero];
        textView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        if (self.defaultText) {
            textView.text = self.defaultText;
            self.defaultText = nil;
        }
        
        [self setTextView:textView];
    }
    return _textView;
}

- (JLTokenizer *)tokenizer
{
    return self.textView.syntaxTokenizer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = self.textView.backgroundColor;
    self.navigationController.navigationBar.translucent = TRUE;
    
    [self registerForKeyboardNotifications];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Content Insets and Keyboard

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification *)notification
{
    NSDictionary* info = [notification userInfo];
    UIScrollView *scrollView = self.textView;
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
    
    //CGPoint caretPosition = [self.textView caretRectForPosition:self.textView.selectedTextRange.start].origin;
    //CGRect caretRect = CGRectMake(caretPosition.x, caretPosition.y, 1, 1);
    //[self.textView scrollRectToVisible:caretRect animated:YES];
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification *)notification
{
    UIScrollView *scrollView = self.textView;
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
}

@end
