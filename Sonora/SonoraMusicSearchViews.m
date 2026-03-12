//
//  SonoraMusicSearchViews.m
//  Sonora
//

#import "SonoraMusicSearchViews.h"

#import "SonoraSettings.h"

static UIColor *SonoraMusicSearchDefaultAccentColor(void) {
    return [UIColor colorWithRed:1.0 green:0.83 blue:0.08 alpha:1.0];
}

static UIColor *SonoraMusicSearchLegacyAccentColorForIndex(NSInteger raw) {
    switch (raw) {
        case 1:
            return [UIColor colorWithRed:0.31 green:0.64 blue:1.0 alpha:1.0];
        case 2:
            return [UIColor colorWithRed:0.22 green:0.83 blue:0.62 alpha:1.0];
        case 3:
            return [UIColor colorWithRed:1.0 green:0.48 blue:0.40 alpha:1.0];
        case 0:
        default:
            return SonoraMusicSearchDefaultAccentColor();
    }
}

static UIColor *SonoraMusicSearchColorFromHexString(NSString *hexString) {
    if (hexString.length == 0) {
        return nil;
    }
    NSString *normalized = [[hexString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([normalized hasPrefix:@"#"]) {
        normalized = [normalized substringFromIndex:1];
    }
    if (normalized.length != 6) {
        return nil;
    }

    unsigned int rgb = 0;
    if (![[NSScanner scannerWithString:normalized] scanHexInt:&rgb]) {
        return nil;
    }

    CGFloat red = ((rgb >> 16) & 0xFF) / 255.0;
    CGFloat green = ((rgb >> 8) & 0xFF) / 255.0;
    CGFloat blue = (rgb & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

static UIColor *SonoraMusicSearchAccentColor(void) {
    UIColor *fromHex = SonoraMusicSearchColorFromHexString(SonoraSettingsAccentHex());
    if (fromHex != nil) {
        return fromHex;
    }
    return SonoraMusicSearchLegacyAccentColorForIndex(SonoraSettingsLegacyAccentColorIndex());
}

static UIFont *SonoraMusicSearchHeadlineFont(CGFloat size) {
    UIFont *font = [UIFont fontWithName:@"YSMusic-HeadlineBold" size:size];
    if (font != nil) {
        return font;
    }
    return [UIFont boldSystemFontOfSize:size];
}

NSString * const SonoraMusicSearchCardCellReuseID = @"SonoraMusicSearchCardCell";
NSString * const SonoraMiniStreamingListCellReuseID = @"SonoraMiniStreamingListCell";
NSString * const SonoraMusicSearchHeaderReuseID = @"SonoraMusicSearchHeader";

@interface SonoraMusicSearchCardCell ()

@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@end

@implementation SonoraMusicSearchCardCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.contentView.backgroundColor = UIColor.clearColor;

    UIImageView *coverView = [[UIImageView alloc] init];
    coverView.translatesAutoresizingMaskIntoConstraints = NO;
    coverView.contentMode = UIViewContentModeScaleAspectFill;
    coverView.clipsToBounds = YES;
    coverView.layer.cornerRadius = 12.0;
    self.coverView = coverView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 1;
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    self.subtitleLabel = subtitleLabel;

    [self.contentView addSubview:coverView];
    [self.contentView addSubview:titleLabel];
    [self.contentView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [coverView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [coverView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [coverView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [coverView.heightAnchor constraintEqualToAnchor:coverView.widthAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:coverView.bottomAnchor constant:8.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor]
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverView.image = nil;
    self.coverView.tintColor = nil;
    self.coverView.backgroundColor = UIColor.clearColor;
    self.coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage * _Nullable)image {
    self.titleLabel.text = title ?: @"";
    self.subtitleLabel.text = subtitle ?: @"";
    if (image != nil) {
        self.coverView.contentMode = UIViewContentModeScaleAspectFill;
        self.coverView.image = image;
    } else {
        UIImage *placeholder = [UIImage systemImageNamed:@"music.note"];
        self.coverView.contentMode = UIViewContentModeCenter;
        self.coverView.image = placeholder;
        self.coverView.tintColor = UIColor.secondaryLabelColor;
        self.coverView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.08];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.04];
        }];
    }
}

@end

@interface SonoraMiniStreamingListCell ()

@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIView *separatorView;

@end

@implementation SonoraMiniStreamingListCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.contentView.backgroundColor = UIColor.clearColor;
    CGFloat separatorHeight = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);

    UIImageView *coverView = [[UIImageView alloc] init];
    coverView.translatesAutoresizingMaskIntoConstraints = NO;
    coverView.contentMode = UIViewContentModeScaleAspectFill;
    coverView.clipsToBounds = YES;
    coverView.layer.cornerRadius = 6.0;
    coverView.layer.masksToBounds = YES;
    self.coverView = coverView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 1;
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    self.subtitleLabel = subtitleLabel;

    UILabel *durationLabel = [[UILabel alloc] init];
    durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
    durationLabel.textColor = UIColor.secondaryLabelColor;
    durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel = durationLabel;

    UIView *separatorView = [[UIView alloc] init];
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    separatorView.backgroundColor = [UIColor separatorColor];
    self.separatorView = separatorView;

    [self.contentView addSubview:coverView];
    [self.contentView addSubview:durationLabel];
    [self.contentView addSubview:separatorView];
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.distribution = UIStackViewDistributionFill;
    textStack.spacing = 2.0;
    [self.contentView addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [coverView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [coverView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [coverView.widthAnchor constraintEqualToConstant:34.0],
        [coverView.heightAnchor constraintEqualToConstant:34.0],

        [durationLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [durationLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [durationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:44.0],

        [textStack.leadingAnchor constraintEqualToAnchor:coverView.trailingAnchor constant:10.0],
        [textStack.trailingAnchor constraintEqualToAnchor:durationLabel.leadingAnchor constant:-8.0],
        [textStack.centerYAnchor constraintEqualToAnchor:coverView.centerYAnchor],

        [separatorView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:62.0],
        [separatorView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [separatorView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [separatorView.heightAnchor constraintEqualToConstant:separatorHeight]
    ]];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverView.image = nil;
    self.coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverView.tintColor = nil;
    self.coverView.backgroundColor = UIColor.clearColor;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.durationLabel.text = nil;
    self.separatorView.hidden = NO;
    self.titleLabel.textColor = UIColor.labelColor;
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
               durationText:(NSString *)durationText
                     image:(UIImage * _Nullable)image
                  isCurrent:(BOOL)isCurrent
     showsPlaybackIndicator:(BOOL)showsPlaybackIndicator
             showsSeparator:(BOOL)showsSeparator {
    self.titleLabel.text = title ?: @"";
    self.subtitleLabel.text = subtitle ?: @"";
    self.durationLabel.text = durationText ?: @"";
    self.subtitleLabel.hidden = (subtitle.length == 0);
    self.separatorView.hidden = !showsSeparator;
    self.titleLabel.textColor = isCurrent ? SonoraMusicSearchAccentColor() : UIColor.labelColor;

    if (showsPlaybackIndicator && isCurrent) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                               weight:UIImageSymbolWeightSemibold];
        self.coverView.image = [UIImage systemImageNamed:@"pause.fill" withConfiguration:config];
        self.coverView.tintColor = UIColor.labelColor;
        self.coverView.backgroundColor = UIColor.clearColor;
        self.coverView.contentMode = UIViewContentModeCenter;
        return;
    }

    if (image != nil) {
        self.coverView.contentMode = UIViewContentModeScaleAspectFill;
        self.coverView.image = image;
        return;
    }

    self.coverView.contentMode = UIViewContentModeCenter;
    self.coverView.image = [UIImage systemImageNamed:@"music.note"];
    self.coverView.tintColor = UIColor.secondaryLabelColor;
    self.coverView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.08];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.04];
    }];
}

@end

@interface SonoraMusicSearchHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation SonoraMusicSearchHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.font = SonoraMusicSearchHeadlineFont(24.0);
        label.textColor = UIColor.labelColor;
        self.titleLabel = label;
        [self addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0.0],
            [label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2.0]
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title {
    self.titleLabel.text = title ?: @"";
}

@end
