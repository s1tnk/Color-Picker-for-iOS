/*-
 * Copyright (c) 2011 Ryota Hayashi
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#import "hayashi311_color_picker_view.h"
#import "hayashi311_cg_util.h"

@interface Hayashi311ColorPickerView()
- (void)initColorCursor;
- (void)Update:(id)sender;
- (void)ClearInput;
- (void)SetCurrentTouchPointInView:(UITouch *)touch;
- (void)CreateCacheImage;
@end

@implementation Hayashi311ColorPickerView

- (id)initWithFrame:(CGRect)frame andDefaultColor:(const Hayashi311RGBColor)default_color
{
    self = [super initWithFrame:frame];
    if (self) {
        default_rgb_color_ = default_color;
        animating_ = FALSE;
        
        // RGBのデフォルトカラーをHSVに変換
        HSVColorFromRGBColor(&default_rgb_color_, &current_hsv_color_);
        
        // パーツの配置
        current_color_frame_ = CGRectMake(10.0f, 30.0f, 40.0f, 40.0f);
        brightness_picker_frame_ = CGRectMake(120.0f, 30.0f, 190.0f, 40.0f);
        brightness_picker_touch_frame_ = CGRectMake(100.0f, 30.0f, 230.0f, 40.0f);
        brightness_picker_shadow_frame_ = CGRectMake(120.0f-5.0f, 30.0f-5.0f, 190.0f+10.0f, 40.0f+10.0f);
        color_map_frame_ = CGRectMake(11.0f, 106.0f, 300.0f, 300.0f);
        color_map_side_frame_ = CGRectMake(10.0f, 105.0f, 300.0f, 300.0f);
        pixel_size_ = 15.0f;
        brightness_lower_limit_ = 0.4f;
        saturation_upper_limit_ = 0.95f;
        
        [self initColorCursor];
        
        // 入力の初期化
        is_tap_start_ = FALSE;
        is_tapped_ = FALSE;
        was_drag_start_ = FALSE;
        is_drag_start_ = FALSE;
        is_dragging_ = FALSE;
        is_drag_end_ = FALSE;
        
        // 諸々初期化
        [self setBackgroundColor:[UIColor colorWithWhite:0.99f alpha:1.0f]];
        [self setMultipleTouchEnabled:FALSE];
        
        show_color_cursor_ = TRUE;
        
        //[self LoopStart];
        
        
        gettimeofday(&last_update_time, NULL);
        
        time_interval.tv_sec = 0.0;
        time_interval.tv_usec = 1000000.0/20.0;
        is_need_redraw_color_map = TRUE;
        color_map_image = NULL;
        
        [self CreateCacheImage];
        
    }
    return self;
}

- (float)BrightnessLowerLimit{
    return brightness_lower_limit_;
}

- (void)setBrightnessLowerLimit:(float)brightness_under_limit{
    brightness_lower_limit_ = brightness_under_limit;
}

- (float)SaturationUpperLimit{
    return brightness_lower_limit_;
}

- (void)setSaturationUpperLimit:(float)saturation_upper_limit{
    saturation_upper_limit_ = saturation_upper_limit;
    [self initColorCursor];
}

- (void)initColorCursor{
    int pixel_count = color_map_frame_.size.height/pixel_size_;
    CGPoint new_position;
    new_position.x = current_hsv_color_.h * (float)pixel_count * pixel_size_ + color_map_frame_.origin.x + pixel_size_/2.0f;
    new_position.y = (1.0f - current_hsv_color_.s) * (1.0f/saturation_upper_limit_) * (float)(pixel_count - 1) * pixel_size_ + color_map_frame_.origin.y + pixel_size_/2.0f;
    color_cursor_position_.x = (int)(new_position.x/pixel_size_) * pixel_size_  + color_map_frame_.origin.x - pixel_size_/2.0f;
    color_cursor_position_.y = (int)(new_position.y/pixel_size_) * pixel_size_ + pixel_size_/2.0f;
}

- (Hayashi311RGBColor)RGBColor{
    Hayashi311RGBColor rgb_color;
    UIColor* color_from_hsv = [UIColor colorWithHue:current_hsv_color_.h saturation:current_hsv_color_.s brightness:current_hsv_color_.v alpha:1.0f];
    RGBColorFromUIColor(color_from_hsv,&rgb_color);
    return rgb_color;
}

- (void)Update:(id)sender{
    timeval now,diff;
    gettimeofday(&now, NULL);
    timersub(&now, &last_update_time, &diff);
    if (timercmp(&diff, &time_interval, >)) {
        last_update_time = now;
    }else{
        return;
    }
    
    if (is_dragging_ || is_drag_start_ || is_drag_end_ || is_tapped_) {
        CGPoint touch_position = active_touch_position_;
        
        if(!show_color_cursor_){
            [self setNeedsDisplay];
            show_color_cursor_ = TRUE;
        }
        
        
        if (CGRectContainsPoint(color_map_frame_,touch_position)) {
            // カラーマップ
            
            // ドラッグ中はカーソルを表示させない
            if (is_dragging_ && !is_drag_end_) {
                //show_color_cursor_ = FALSE;
            }
            
            int pixel_count = color_map_frame_.size.height/pixel_size_;
            Hayashi311HSVColor new_hsv = current_hsv_color_;
            
            CGPoint new_position = CGPointMake(touch_position.x - color_map_frame_.origin.x, touch_position.y - color_map_frame_.origin.y);
            /*
            new_hsv.h = (int)((new_position.x)/pixel_size_) / (float)pixel_count;
            new_hsv.s = 1.0f-(int)((new_position.y)/pixel_size_) / (float)pixel_count;
            */
            
            float pixel_x = (int)((new_position.x)/pixel_size_)/(float)pixel_count; // X(色相)は1.0f=0.0fなので0.0f~0.95fの値をとるように
            float pixel_y = (int)((new_position.y)/pixel_size_)/(float)(pixel_count-1); // Y(彩度)は0.0f~1.0f
            
            HSVColorAt(&new_hsv, pixel_x, pixel_y, saturation_upper_limit_, current_hsv_color_.v);
            
            if (!isEqual(&new_hsv,&current_hsv_color_)) {
                current_hsv_color_ = new_hsv;
                color_cursor_position_.x = (int)(new_position.x/pixel_size_) * pixel_size_  + color_map_frame_.origin.x + pixel_size_/2.0f;
                color_cursor_position_.y = (int)(new_position.y/pixel_size_) * pixel_size_ + color_map_frame_.origin.y + pixel_size_/2.0f;
                
                [self setNeedsDisplay];
            }
        }else if(CGRectContainsPoint(brightness_picker_touch_frame_,touch_position)){
            if (CGRectContainsPoint(brightness_picker_frame_,touch_position)) {
                // 輝度のスライダーの内側
                current_hsv_color_.v = (1.0f - ((touch_position.x - brightness_picker_frame_.origin.x )/ brightness_picker_frame_.size.width )) * (1.0f - brightness_lower_limit_) + brightness_lower_limit_;
            }else{
                // 左右をタッチした場合
                if (touch_position.x < brightness_picker_frame_.origin.x) {
                    current_hsv_color_.v = 1.0f;
                }else if((brightness_picker_frame_.origin.x + brightness_picker_frame_.size.width) < touch_position.x){
                    current_hsv_color_.v = brightness_lower_limit_;
                }
            }
            is_need_redraw_color_map = TRUE;
            [self setNeedsDisplay];
        }
    }
    [self ClearInput];
}

- (void)CreateCacheImage
{
    // 影
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(brightness_picker_shadow_frame_.size.width,
                                                      brightness_picker_shadow_frame_.size.height),
                                           FALSE,
                                           2.0f);
    CGContextRef brightness_picker_shadow_context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(brightness_picker_shadow_context, 0, brightness_picker_shadow_frame_.size.height);
    CGContextScaleCTM(brightness_picker_shadow_context, 1.0, -1.0);
    
    Hayashi311SetRoundedRectanglePath(brightness_picker_shadow_context, 
                                      CGRectMake(0.0f, 0.0f,
                                                 brightness_picker_shadow_frame_.size.width,
                                                 brightness_picker_shadow_frame_.size.height), 5.0f);
    CGContextSetLineWidth(brightness_picker_shadow_context, 10.0f);
    CGContextSetShadow(brightness_picker_shadow_context, CGSizeMake(0.0f, 0.0f), 10.0f);
    CGContextDrawPath(brightness_picker_shadow_context, kCGPathStroke);
    
    brightness_picker_shadow_image = CGBitmapContextCreateImage(brightness_picker_shadow_context);
    UIGraphicsEndImageContext();
    
}

- (void)drawRect:(CGRect)rect
{
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    Hayashi311RGBColor current_rgb_color = [self RGBColor];
    
    /////////////////////////////////////////////////////////////////////////////
    //
    // 輝度
    //
    /////////////////////////////////////////////////////////////////////////////
    
    CGContextSaveGState(context);
    
    Hayashi311SetRoundedRectanglePath(context, brightness_picker_frame_, 5.0f);
    CGContextClip(context);
    
    CGGradientRef gradient;
    CGColorSpaceRef colorSpace;
    size_t num_locations = 2;
    CGFloat locations[2] = { 0.0, 1.0 };
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    Hayashi311RGBColor dark_color;
    Hayashi311RGBColor light_color;
    UIColor* dark_color_from_hsv = [UIColor colorWithHue:current_hsv_color_.h saturation:current_hsv_color_.v brightness:brightness_lower_limit_ alpha:1.0f];
    UIColor* light_color_from_hsv = [UIColor colorWithHue:current_hsv_color_.h saturation:current_hsv_color_.s brightness:1.0f alpha:1.0f];
    
    RGBColorFromUIColor(dark_color_from_hsv, &dark_color);
    RGBColorFromUIColor(light_color_from_hsv, &light_color);
    
    CGFloat gradient_color_[] = {
        dark_color.r,dark_color.g,dark_color.b,1.0f,
        light_color.r,light_color.g,light_color.b,1.0f,
    };
    
    gradient = CGGradientCreateWithColorComponents(colorSpace, gradient_color_,
                                                   locations, num_locations);
    
    CGPoint startPoint = CGPointMake(brightness_picker_frame_.origin.x + brightness_picker_frame_.size.width, brightness_picker_frame_.origin.y);
    CGPoint endPoint = CGPointMake(brightness_picker_frame_.origin.x, brightness_picker_frame_.origin.y);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    
    // GradientとColorSpaceを開放する
    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);
    
    // 輝度の内側の影
    CGContextDrawImage(context, brightness_picker_shadow_frame_, brightness_picker_shadow_image);
    
    // 現在の輝度を示す
    float pointer_size = 5.0f;
    float tappoint_x = (1.0f - (current_hsv_color_.v - brightness_lower_limit_)/(1.0f - brightness_lower_limit_)) * brightness_picker_frame_.size.width + brightness_picker_frame_.origin.x;
    
    CGRect rect_ellipse = CGRectMake( tappoint_x - pointer_size,brightness_picker_frame_.origin.y + brightness_picker_frame_.size.height/2.0f - pointer_size, pointer_size*2, pointer_size*2);
    [[UIColor whiteColor] set];
    CGContextSetShadow(context, CGSizeMake(0.0f, 1.0f), 5.0f);
    CGContextAddEllipseInRect(context, rect_ellipse);
    CGContextDrawPath(context, kCGPathFill);
    
    CGContextRestoreGState(context);
    
    
    CGContextSaveGState(context);
    
    CGContextRestoreGState(context);
    
    
     
    
    /////////////////////////////////////////////////////////////////////////////
    //
    // カラーマップ
    //
    /////////////////////////////////////////////////////////////////////////////
    
    // 広い面積に描画する時はCGContextAddRectよりCGContextAddLinesの方がパフォーマンスがいい(気がする)
    CGContextSaveGState(context);
    
    [[UIColor colorWithWhite:0.9f alpha:1.0f] set];
    //[[UIColor lightTextColor] set];
    //CGContextSetShadow(context, CGSizeMake(0.0f, 0.0f), 4.0f);
    //CGContextAddRect(context, color_map_side_frame_);
    CGPoint points[] = {
                        color_map_side_frame_.origin.x,color_map_side_frame_.origin.y,
                        color_map_side_frame_.origin.x + color_map_side_frame_.size.width,color_map_side_frame_.origin.y,
                        color_map_side_frame_.origin.x + color_map_side_frame_.size.width,color_map_side_frame_.origin.y +color_map_side_frame_.size.height,
                        color_map_side_frame_.origin.x,color_map_side_frame_.origin.y+color_map_side_frame_.size.height,
                        color_map_side_frame_.origin.x,color_map_side_frame_.origin.y,
    };
    CGContextAddLines(context, points, 5);
    CGContextDrawPath(context, kCGPathStroke);
    
    CGContextRestoreGState(context);
     
     
    /*
    CGContextSaveGState(context);
    float height;
    int pixel_count = color_map_frame_.size.height/pixel_size_;
    
    for (int j = 0; j < pixel_count; ++j) {
        height =  pixel_size_ * j + color_map_frame_.origin.y;
        float pixel_y = (float)j/(pixel_count-1); // Y(彩度)は0.0f~1.0f
        for (int i = 0; i < pixel_count; ++i) {
            float pixel_x = (float)i/pixel_count; // X(色相)は1.0f=0.0fなので0.0f~0.95fの値をとるように
            Hayashi311HSVColor pixel_hsv;
            HSVColorAt(&pixel_hsv, pixel_x, pixel_y, saturation_upper_limit_, current_hsv_color_.v);
            CGContextSetFillColorWithColor(context, [UIColor colorWithHue:pixel_hsv.h saturation:pixel_hsv.s brightness:pixel_hsv.v alpha:1.0f].CGColor);
            
            //CGContextAddRect(context, CGRectMake(pixel_size_*i+color_map_frame_.origin.x, height, pixel_size_-2.0f, pixel_size_-2.0f));
            CGContextAddRect(context, CGRectMake(pixel_size_*i+color_map_frame_.origin.x, height, pixel_size_-2.0f, pixel_size_-2.0f));
            CGContextDrawPath(context, kCGPathFill);
        }
    }
    
    CGContextRestoreGState(context);
    
     */
    
    // コンテキストを生成してcolor_map_imageに流し込む
    // UIGraphicsBeginImageContextWithOptionsで一時的に書き出すコンテキストの解像度を変更できる
    // 低解像度のコンテキストに書き出した方がパフォーマンスが高いかもと思ったけども
    // 書き出した画像をレンダリングする時に、拡大処理が走るのでかえって遅くなった
    if (is_need_redraw_color_map) {
        is_need_redraw_color_map = FALSE;
        if (color_map_image != NULL) {
            CGImageRelease(color_map_image);
        }
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(color_map_frame_.size.width-1.0f, color_map_frame_.size.height-1.0f),
                                               YES,
                                               [[UIScreen mainScreen] scale]);
        CGContextRef cmap_context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(cmap_context, 0, color_map_frame_.size.height);
        CGContextScaleCTM(cmap_context, 1.0, -1.0);
        
        CGContextSetFillColorWithColor(cmap_context, [self backgroundColor].CGColor);
        CGContextFillRect(cmap_context, CGRectMake(0.0f, 0.0f, color_map_frame_.size.width, color_map_frame_.size.height));
        
        CGContextSaveGState(cmap_context);
        float height;
        int pixel_count = color_map_frame_.size.height/pixel_size_;
        
        for (int j = 0; j < pixel_count; ++j) {
            height =  pixel_size_ * j;
            float pixel_y = (float)j/(pixel_count-1); // Y(彩度)は0.0f~1.0f
            for (int i = 0; i < pixel_count; ++i) {
                float pixel_x = (float)i/pixel_count; // X(色相)は1.0f=0.0fなので0.0f~0.95fの値をとるように
                Hayashi311HSVColor pixel_hsv;
                HSVColorAt(&pixel_hsv, pixel_x, pixel_y, saturation_upper_limit_, current_hsv_color_.v);
                CGContextSetFillColorWithColor(cmap_context, [UIColor colorWithHue:pixel_hsv.h saturation:pixel_hsv.s brightness:pixel_hsv.v alpha:1.0f].CGColor);
                
                //CGContextAddRect(context, CGRectMake(pixel_size_*i+color_map_frame_.origin.x, height, pixel_size_-2.0f, pixel_size_-2.0f));
                CGContextAddRect(cmap_context, CGRectMake(pixel_size_*i, height, pixel_size_-2.0f, pixel_size_-2.0f));
                //CGContextAddRect(cmap_context, CGRectMake(pixel_size_*i, height, pixel_size_, pixel_size_));
                CGContextDrawPath(cmap_context, kCGPathFill);
            }
        }
        
        CGContextRestoreGState(cmap_context);
        color_map_image = CGBitmapContextCreateImage(cmap_context);
        UIGraphicsEndImageContext();
    }
    CGContextDrawImage(context, CGRectMake(color_map_frame_.origin.x, color_map_frame_.origin.y, color_map_frame_.size.width-1.0f, color_map_frame_.size.height-1.0f), color_map_image);
    
    
    /////////////////////////////////////////////////////////////////////////////
    //
    // カレントのカラー
    //
    /////////////////////////////////////////////////////////////////////////////
    
    CGContextSaveGState(context);
    Hayashi311DrawSquareColorBatch(context, CGPointMake(CGRectGetMidX(current_color_frame_), CGRectGetMidY(current_color_frame_)), &current_rgb_color, current_color_frame_.size.width/2.0f);
    CGContextRestoreGState(context);
    
    /////////////////////////////////////////////////////////////////////////////
    //
    // RGBのパーセント表示
    //
    /////////////////////////////////////////////////////////////////////////////
    
    [[UIColor darkGrayColor] set];
    
    float text_height = 20.0f;
    float text_center = CGRectGetMidY(current_color_frame_) - 5.0f;
    [[NSString stringWithFormat:@"R:%3d%%",(int)(current_rgb_color.r*100)] drawAtPoint:CGPointMake(current_color_frame_.origin.x+current_color_frame_.size.width+10.0f, text_center - text_height) withFont:[UIFont boldSystemFontOfSize:12.0f]];
    [[NSString stringWithFormat:@"G:%3d%%",(int)(current_rgb_color.g*100)] drawAtPoint:CGPointMake(current_color_frame_.origin.x+current_color_frame_.size.width+10.0f, text_center) withFont:[UIFont boldSystemFontOfSize:12.0f]];
    [[NSString stringWithFormat:@"B:%3d%%",(int)(current_rgb_color.b*100)] drawAtPoint:CGPointMake(current_color_frame_.origin.x+current_color_frame_.size.width+10.0f, text_center + text_height) withFont:[UIFont boldSystemFontOfSize:12.0f]];
    
    /////////////////////////////////////////////////////////////////////////////
    //
    // カーソル
    //
    /////////////////////////////////////////////////////////////////////////////
    
    if (show_color_cursor_) {
        float cursor_size = pixel_size_ + 2.0f;
        float cursor_back_size = cursor_size + 8.0f;
        // 隙間分引く
        CGRect cursor_back_rect = CGRectMake(color_cursor_position_.x - cursor_back_size/2.0f -1.0f, color_cursor_position_.y - cursor_back_size/2.0f -1.0f, cursor_back_size, cursor_back_size);
        CGRect cursor_rect = CGRectMake(color_cursor_position_.x - cursor_size/2.0f -1.0f, color_cursor_position_.y - cursor_size/2.0f -1.0f, cursor_size, cursor_size);
        
        CGContextSaveGState(context);
        CGContextAddRect(context, cursor_back_rect);
        [[UIColor whiteColor] set];
        CGContextSetShadow(context, CGSizeMake(0.0f, 1.0f), 3.0f);
        CGContextDrawPath(context, kCGPathFill);
        CGContextRestoreGState(context);
        
        CGContextSaveGState(context);
        CGContextAddRect(context, cursor_rect);
        [[UIColor colorWithRed:current_rgb_color.r green:current_rgb_color.g blue:current_rgb_color.b alpha:1.0f] set];
        CGContextDrawPath(context, kCGPathFill);
        CGContextRestoreGState(context);
    }
}


/////////////////////////////////////////////////////////////////////////////
//
// 入力
//
/////////////////////////////////////////////////////////////////////////////

- (void)ClearInput{
    is_tap_start_ = FALSE;
    is_tapped_ = FALSE;
    is_drag_start_ = FALSE;
	is_drag_end_ = FALSE;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    if ([touches count] == 1) {
        UITouch* touch = [touches anyObject];
        [self SetCurrentTouchPointInView:touch];
        was_drag_start_ = TRUE;
        is_tap_start_ = TRUE;
        touch_start_position_.x = active_touch_position_.x;
        touch_start_position_.y = active_touch_position_.y;
    }
    [self Update:self];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
	UITouch* touch = [touches anyObject];
    if ([touch tapCount] == 1) {
        is_dragging_ = TRUE;
        if (was_drag_start_) {
            was_drag_start_ = FALSE;
            is_drag_start_ = TRUE;
        }
        [self SetCurrentTouchPointInView:[touches anyObject]];
    }
    [self Update:self];
    
    [self setNeedsDisplay];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
	UITouch* touch = [touches anyObject];
    
    if (is_dragging_) {
        is_drag_end_ = TRUE;
        
        [NSTimer scheduledTimerWithTimeInterval:1.0/20.0 target:self selector:@selector(Update:) userInfo:nil repeats:FALSE];
}else{
        if ([touch tapCount] == 1) {
            is_tapped_ = TRUE;
        }
    }
    is_dragging_ = FALSE;
    [self SetCurrentTouchPointInView:touch];
    [self Update:self];
}

- (void)SetCurrentTouchPointInView:(UITouch *)touch{
    CGPoint point;
	point = [touch locationInView:self];
    active_touch_position_.x = point.x;
    active_touch_position_.y = point.y;
}

- (void)BeforeDealloc{
    //[self LoopStop];
}


- (void)dealloc{
    if (color_map_image != NULL) {
        CGImageRelease(color_map_image);
    }
    CGImageRelease(brightness_picker_shadow_image);
    
    [super dealloc];
}

@end
