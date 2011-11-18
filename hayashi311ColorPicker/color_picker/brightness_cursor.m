//
//  brightness_cursor.m
//  hayashi311ColorPicker
//
//  Created by 林 亮太 on 11/11/18.
//  Copyright (c) 2011 Hayashi Ryota. All rights reserved.
//

#import "brightness_cursor.h"

@implementation BrightnessCursor

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    float pointer_size = 5.0f;
    
    CGRect rect_ellipse = CGRectMake( 5.0f,5.0f, pointer_size*2, pointer_size*2);
    [[UIColor whiteColor] set];
    CGContextSetShadow(context, CGSizeMake(0.0f, 1.0f), 5.0f);
    CGContextAddEllipseInRect(context, rect_ellipse);
    CGContextDrawPath(context, kCGPathFill);
    
}


@end
