

#import "JLTextView.h"
#import "Helpers.h"
#import "TextLineCell.h"
#import "JLTokenizer.h"

#define EMPTY @""

@interface JLTextView () {
    id internalDelegate;
}

@property (nonatomic, strong) NSMutableArray *lines;
@property (nonatomic, strong) NSMutableArray *lineLayers;
@property (nonatomic, strong) NSMutableArray *lineLayerIndex;
@property (nonatomic, strong) NSMutableArray *lineStartIndexes;
@end

@implementation TextViewChange


@end

@implementation JLTextView {
    
    CGFloat lastUpdateOffset;
    CGFloat currentOffset;
    
    CGFloat _lineHeight;
    CGFloat _charWidth;
    
    CTFramesetterRef    _framesetter; // Cached Core Text framesetter
    
    UIView *_debugView;
    
    NSUInteger textLength;
    
}
@synthesize attributes = _attributes, syntaxTokenizer = _syntaxTokenizer;

#pragma mark –

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.tableView setContentOffset:self.contentOffset];
}

// Helper method
- (void)setRange:(NSRange)range forLineWithIndex:(int)i
{
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)([self.attributedString attributedSubstringFromRange:range]));
    self.lines[i] = (__bridge id)(line);
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

// This is probably not helpful at all
- (void)reloadLineWithIndex:(int)index
{
    NSRange range = [self rangeOfLineWithIndex:index];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)([self.attributedString attributedSubstringFromRange:range]));
    self.lines[index] = (__bridge id)(line);
}

- (void)deleteLineWithNumber:(int)i
{
    [self.lines removeObjectAtIndex:i];
    [self.lineStartIndexes removeObjectAtIndex:i];
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
}

- (void)insertLineWithRange:(NSRange)range atIndex:(int)i
{
    NSAttributedString *string;
    
    if (range.location != NSNotFound && range.length < self.attributedString.length) string = [self.attributedString attributedSubstringFromRange:range];
    else @throw [NSException exceptionWithName:@"JLTextViewException" reason:@"A new line was created, but its assigned range is invalid" userInfo:nil];
    
    
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)(string));
    
    [self.lines insertObject:(__bridge id)(line) atIndex:i];
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    [self.lineStartIndexes insertObject:@(range.location) atIndex:i];
}

- (NSRange)rangeOfLineWithIndex:(int)index
{
    CTLineRef currentLine = (__bridge CTLineRef)(self.lines[index]);
    NSRange range = NSMakeRange([(NSNumber *)self.lineStartIndexes[index] intValue], CTLineGetStringRange(currentLine).length);
    return range;
}

- (void)offsetLineRangeLocationsFromLine:(int)index offset:(int)offset
{
    for (int j = index; j < self.lineStartIndexes.count; j++) {
        _lineStartIndexes[j] = @([(NSNumber *)[self.lineStartIndexes objectAtIndex:j] intValue] + offset);
    }
}

- (void)updatLineWithIndex:(int)i andRecentTextChange:(TextViewChange *)options
{
    NSString *replacementText = options.replacementText;
    NSRange range = options.range;
    
    CTLineRef currentLine = (__bridge CTLineRef)(self.lines[i]);
    NSInteger offset = options.replacementText.length - options.range.length;

    NSAssert(currentLine != nil, @"The current line cannot be found");
    
    NSRange currentLineRange = [self rangeOfLineWithIndex:i];
    currentLineRange.length += offset;
    
    NSRange newWord = NSMakeRange(options.range.location, options.replacementText.length);
    
    // TEST
    if (currentLineRange.length == 0)
    {
        [self deleteLineWithNumber:i];
        return;
    }
    
    //NSLog(@"Length of current line #%i is: %i",i,currentLineRange.length);
    //NSLog(@"Current line contains \"%@\"", [self.attributedString attributedSubstringFromRange:currentLineRange]);
    
    if (currentLineRange.length == INT_MAX || currentLineRange.length > textLength)
    {
        @throw [NSException exceptionWithName:@"JLTextViewException" reason:@"The range of the current line is incorrect" userInfo:@{@"Range" : NSStringFromRange(currentLineRange)}];
    }
    // BACKSPACE
    if ([replacementText isEqualToString:@""] && range.length == 1)
    {
        if (range.location >= currentLineRange.location)
        {
            // No text changes line
            [self setRange:currentLineRange forLineWithIndex:i];
            return;
        }
        else {
            
            // TODO: Involve a typesetter here
            
            CTLineRef previousLine = (__bridge CTLineRef)(self.lines[i-1]);
            NSAssert(previousLine != nil, @"The current line cannot be found");
            
            NSRange previousLineRange = [self rangeOfLineWithIndex:i-1];
            NSRange mergedLineRange = NSMakeRange(previousLineRange.location, NSMaxRange(currentLineRange)-previousLineRange.location);
            /*
            NSRange nextLineRange = [self rangeOfLineWithIndex:i+1];
            
            NSLog(@"Merging to line %i with range: %@ text:%@", i-1, NSStringFromRange(mergedLineRange),[self.attributedString.string substringWithRange:mergedLineRange]);
            NSLog(@"Deleting line %i with range: %@ text:%@", i, NSStringFromRange(currentLineRange), [self.attributedString.string substringWithRange:currentLineRange]);
            NSLog(@"Next line %i with range: %@ text:%@", i+1, NSStringFromRange(nextLineRange), [self.attributedString.string substringWithRange:nextLineRange]);
            */
            
            [self setRange:mergedLineRange forLineWithIndex:i-1];
            [self deleteLineWithNumber:i];
            return;
        }
    }
    
    // NEWLINE
    if ([replacementText isEqualToString:@"\n"]) {
        
        NSRange range1 = NSMakeRange(currentLineRange.location, NSMaxRange(newWord) - currentLineRange.location);
        NSRange range2 = NSMakeRange(NSMaxRange(newWord), NSMaxRange(currentLineRange)-NSMaxRange(newWord));
        
        [self setRange:range1 forLineWithIndex:i];
        [self insertLineWithRange:range2 atIndex:i+1];
        
        return;
        
    }
    
    float maxWidth = self.frame.size.width - 2*MARGIN;
    float currentEstimatedWidth = currentLineRange.length * _charWidth;
    
    // This seems to estimate the lineWidth to be too large.
    // If the estimatedWith is clearly less than the maxWidth there is no need to involve the typesetter.
    if (currentEstimatedWidth < maxWidth) {
        [self setRange:currentLineRange forLineWithIndex:i];
        return;
    }
    
    // We're not sure, but the line may be overflowing. Use the typesetter.
    
    NSAttributedString *currentLineString = [self.attributedString attributedSubstringFromRange:currentLineRange];
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)(currentLineString));
    CFIndex length = CTTypesetterSuggestLineBreak(typesetter, 0, self.frame.size.width-2*MARGIN);
    
    if (length < currentLineRange.length) {
        NSRange range1 = NSMakeRange(currentLineRange.location, length);
        NSRange range2 = NSMakeRange(NSMaxRange(range1), NSMaxRange(currentLineRange)-NSMaxRange(range1));
        
        [self setRange:range1 forLineWithIndex:i];
        [self insertLineWithRange:range2 atIndex:i+1];
        return;
    }
    else {
        [self setRange:currentLineRange forLineWithIndex:i];
        return;
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    //TODO: deactivate core-text overlay upon failure
    //TODO: Nicer designflow
    //TODO: Handle out of bound errors
    
    //Basic stuff, tokenize the string
    TextViewChange *options = [[TextViewChange alloc] init];
    options.replacementText = text;
    options.range = range;
    
    [self.attributedString replaceCharactersInRange:range withAttributedString:[[NSAttributedString alloc] initWithString:text attributes:_attributes]];
    _attributedString = [self.syntaxTokenizer tokenizeAttributedString:self.attributedString withRecentTextViewChange:options];
    
    NSInteger lineIndex = [self lineNumberAtIndex:NSMaxRange(range)];
    NSInteger offset = text.length - range.length;
    
    // Check if multiple lines are changed
    if (range.length > 1)
    {
        NSInteger firstLine = [self lineNumberAtIndex:range.location];
        // TODO: Handle cases where the range reaches across multiple lines
    }

    [self offsetLineRangeLocationsFromLine:lineIndex + 1 offset:offset];
    [self updatLineWithIndex:lineIndex andRecentTextChange:options];
    
	return YES;
}

#pragma mark - TableView



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _lineHeight;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.lines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"LineLayer";
    TextLineCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier
                                                           forIndexPath:indexPath];
    
    NSUInteger lineNumber = indexPath.row;
    CTLineRef ref = (__bridge CTLineRef)([self.lines objectAtIndex:lineNumber]);
    cell.line = ref;
    [cell setNeedsDisplay];
    
    return cell;
}

#pragma mark -

// Helper method to release our cached Core Text framesetter and frame
- (void)clearPreviousLayoutInformation
{
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
}

- (NSUInteger)lineNumberAtIndex:(NSUInteger)index
{
    for (int i = 0; i < self.lineStartIndexes.count; i++) {
        if ([(NSNumber *)self.lineStartIndexes[i] intValue] > index) return i-1;
    }
    return 0;
}

NS_INLINE NSRange NSRangeFromCFRange(CFRange range) {
    return NSMakeRange(range.location, range.length);
}

- (void)generateLines
{
    if (!self.attributedString) return;
    
    [self clearPreviousLayoutInformation];
    self.lines = @[].mutableCopy;
    self.lineStartIndexes = @[].mutableCopy;
    
    CFAttributedStringRef ref = (CFAttributedStringRef)CFBridgingRetain(self.attributedString);
    _framesetter = CTFramesetterCreateWithAttributedString(ref);
    
    // Work out the geometry
    CGRect insetBounds = CGRectInset([self bounds], MARGIN, MARGIN);
    CGFloat boundsWidth = CGRectGetWidth(insetBounds);
    
    // Calculate the lines
    CFIndex start = 0;
    NSUInteger length = CFAttributedStringGetLength((__bridge CFAttributedStringRef)(self.attributedString));
    while (start < length)
    {
        CTTypesetterRef typesetter = CTFramesetterGetTypesetter(_framesetter);
        CFIndex count = CTTypesetterSuggestLineBreak(typesetter, start, boundsWidth);
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)([self.attributedString attributedSubstringFromRange:NSMakeRange(start, count)]));
        
        //NSString *string = [self.text substringWithRange:NSMakeRange(start, count)];
        //if ([string rangeOfString:@"\n"].location != NSNotFound) NSLog(@"YES");
        //else NSLog(@"NO");
        
        [self.lines addObject:(__bridge id)(line)];
        [self.lineStartIndexes addObject:@(start)];
        
        start += count;
    }
}

#pragma mark -

- (void)layoutSubviews
{
    // This feels a bit strange. The tableview should maybe not be a subview of the tableView so that it doesn't move?
    self.tableView.frame = self.bounds;
}

- (UITableView *)tableView
{
    if (!_tableView) {
        
        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        [_tableView registerClass:[TextLineCell class] forCellReuseIdentifier:@"LineLayer"];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        
        _tableView.userInteractionEnabled = NO;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 8)];
        
        [self addSubview:_tableView];
    }
    return _tableView;
}


#pragma mark –

- (void)setAttributedString:(NSMutableAttributedString *)attributedString
{
    textLength = attributedString.length;
    _attributedString = attributedString;
    [self generateLines];
    [self.tableView reloadData];
}

- (void)setAttributes:(NSDictionary *)attributes
{
    _attributes = attributes;
}

- (NSDictionary *)attributes
{
    if (!_attributes) {
        //Set line height, font, color and break mode
        CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName,self.font.pointSize,NULL);
        CGFloat minimumLineHeight = [@"a" sizeWithFont:self.font].height,maximumLineHeight = minimumLineHeight;
        CTLineBreakMode lineBreakMode = kCTLineBreakByWordWrapping;
        
        _lineHeight = minimumLineHeight;
        _charWidth = [@"a" sizeWithFont:self.font].width;
        
        //Apply paragraph settings
        CTParagraphStyleRef style = CTParagraphStyleCreate((CTParagraphStyleSetting[3]){
            {kCTParagraphStyleSpecifierMinimumLineHeight,sizeof(minimumLineHeight),&minimumLineHeight},
            {kCTParagraphStyleSpecifierMaximumLineHeight,sizeof(maximumLineHeight),&maximumLineHeight},
            {kCTParagraphStyleSpecifierLineBreakMode,sizeof(CTLineBreakMode),&lineBreakMode}
        },3);
        
        self.attributes = @{(NSString*)kCTFontAttributeName: (__bridge id)font,(NSString*)kCTForegroundColorAttributeName: (__bridge id)[UIColor blackColor].CGColor,(NSString*)kCTParagraphStyleAttributeName: (__bridge id)style};
        
    }
    return _attributes;
}

- (JLTokenizer *)syntaxTokenizer
{
    if (!_syntaxTokenizer) self.syntaxTokenizer = [JLTokenizer new];
    return _syntaxTokenizer;
}

- (void)setSyntaxTokenizer:(JLTokenizer *)syntaxTokenizer
{
    _syntaxTokenizer = syntaxTokenizer;
    _syntaxTokenizer.textView = self;
}

- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    
    //Refresh attributes
    _attributes = nil;
    [self attributes];
}

- (void)refreshTokenization
{
    self.attributedString = [self.syntaxTokenizer tokenizeAttributedString:self.attributedString withRecentTextViewChange:nil];
    self.backgroundColor = self.syntaxTokenizer.backgroundColor;
    [self.tableView setBackgroundColor:self.syntaxTokenizer.backgroundColor];
}

-(id)init {
    self = [super init];
    if(self) {
        [self setup];
    }
    return self;
}
- (id)initWithCoder:(NSCoder*)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self setup];
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setup];
}

- (void)setup
{
    self.textColor = [UIColor clearColor];
    self.delegate = self;
    self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    
    _debugView = [[UIView alloc] init];
    [self addSubview:_debugView];
}

- (void)setText:(NSString *)text
{
    [super setText:text];
    
    _attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:self.attributes];
    self.attributedString = [self.syntaxTokenizer tokenizeAttributedString:_attributedString withRecentTextViewChange:nil];
    [self generateLines];
}
@end

