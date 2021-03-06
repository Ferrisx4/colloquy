#import "CQChatTableCell.h"

#import "CQChatController.h"
#import "CQUnreadCountView.h"

#import <ChatCore/MVChatUser.h>

#import "UIViewAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQChatTableCell {
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	CQUnreadCountView *_unreadCountView;
	NSMutableArray <UILabel *> *_chatPreviewLabels;
	NSUInteger _maximumMessagePreviews;
	BOOL _showsUserInMessagePreviews;
	BOOL _available;
	BOOL _animating;
}

#pragma mark -

+ (UIFont *) previewLabelFont {
	return [UIFont systemFontOfSize:14.];
}

+ (UIFont *) nameLabelFont {
	return [UIFont boldSystemFontOfSize:18.];
}

- (instancetype) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *__nullable) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_unreadCountView = [[CQUnreadCountView alloc] initWithFrame:CGRectZero];

	_maximumMessagePreviews = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQPreviewLinesCount"];
	_showsUserInMessagePreviews = YES;
	_available = YES;

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_nameLabel];
	[self.contentView addSubview:_unreadCountView];

	_nameLabel.font = [[self class] nameLabelFont];
	_nameLabel.textColor = self.textLabel.textColor;
	_nameLabel.highlightedTextColor = self.textLabel.highlightedTextColor;

	_chatPreviewLabels = [[NSMutableArray alloc] init];

	return self;
}

#pragma mark -

- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller {
	self.name = controller.title;
	self.icon = controller.icon;
	self.available = controller.available;

	if ([controller respondsToSelector:@selector(unreadCount)])
		self.unreadCount = controller.unreadCount;
	else self.unreadCount = 0;

	if ([controller respondsToSelector:@selector(importantUnreadCount)])
		self.importantUnreadCount = controller.importantUnreadCount;
	else self.importantUnreadCount = 0;

	if (self.importantUnreadCount && !self.unreadCount)
		self.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@: %u highlighted messages.", @"Voiceover highlights in chat label"), self.name, self.importantUnreadCount];
	else if (self.importantUnreadCount && self.unreadCount)
		self.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@: %u highlighted and %u unread messages.", @"Voiceover highlights and unread messages in chat label"), self.name, self.importantUnreadCount, self.unreadCount];
	else if (self.unreadCount)
		self.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%@: %u unread messages.", @"Voiceover unread messages in chat label"), self.name, self.unreadCount];
	else self.accessibilityLabel = self.name;
}

- (BOOL) showsIcon {
	return !_iconImageView.hidden;
}

- (void) setShowsIcon:(BOOL) show {
	_iconImageView.hidden = !show;

	[self setNeedsLayout];
}

- (NSString *) name {
	return _nameLabel.text;
}

- (void) setName:(NSString *) name {
	_nameLabel.text = name;
}

- (UIImage *__nullable) icon {
	return _iconImageView.image;
}

- (void) setIcon:(UIImage *__nullable) icon {
	if (_iconImageView.image != icon)
		_iconImageView.image = icon;
}

- (NSUInteger) unreadCount {
	return _unreadCountView.count;
}

- (void) setUnreadCount:(NSUInteger) messages {
	_unreadCountView.count = messages;

	[self setNeedsLayout];
}

- (NSUInteger) importantUnreadCount {
	return _unreadCountView.importantCount;
}

- (void) setImportantUnreadCount:(NSUInteger) messages {
	_unreadCountView.importantCount = messages;

	[self setNeedsLayout];
}

- (void) setAvailable:(BOOL) available {
	_available = available;

	CGFloat alpha = (available ? 1. : 0.5);
	_nameLabel.alpha = alpha;
	_iconImageView.alpha = alpha;

	for (UILabel *label in _chatPreviewLabels)
		label.alpha = alpha;
}

#pragma mark -

#define LABEL_SPACING 2.

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated {
	NSString *labelText = nil;
	if (user && action)
		labelText = [NSString stringWithFormat:@"%C %@ %@", (unichar)0x2022, user.displayName, message];
	else if (user && _showsUserInMessagePreviews)
		labelText = [NSString stringWithFormat:@"%@: %@", user.displayName, message];
	else labelText = message;

	if (_animating) {
		for (NSUInteger i = 0; i < _chatPreviewLabels.count; ++i) {
			if (i == 0)
				continue;

			UILabel *currentLabel = _chatPreviewLabels[i];
			UILabel *previousLabel = _chatPreviewLabels[(i - 1)];
			previousLabel.text = currentLabel.text;

			if (i == (_chatPreviewLabels.count - 1))
				currentLabel.text = labelText;
		}

		return;
	}

	if (animated)
		_animating = YES;

	NSTimeInterval animationDelay = 0.;
	NSUInteger labelCount = _chatPreviewLabels.count;
	if (labelCount && labelCount >= _maximumMessagePreviews) {
		UILabel *firstLabel = _chatPreviewLabels.firstObject;
		[_chatPreviewLabels removeObjectAtIndex:0];

		if (cq_shouldAnimate(animated)) {
			[UIView animateWithDuration:.2 delay:0. options:UIViewAnimationOptionCurveEaseOut animations:^{
				firstLabel.alpha = 0.;
			} completion:^(BOOL finished) {
				[firstLabel removeFromSuperview];
			}];

			animationDelay = 0.15;
		} else {
			[firstLabel removeFromSuperview];
		}
	}

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.font = [[self class] previewLabelFont];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor colorWithWhite:(150. / 255.) alpha:1.];
	label.alpha = (animated ? 0. : (_available ? 1. : 0.5));
	label.text = labelText;

	[self.contentView addSubview:label];
	[_chatPreviewLabels addObject:label];

	[self layoutSubviewsWithAnimation:animated withDelay:animationDelay];

	if (cq_shouldAnimate(animated)) {
		[UIView animateWithDuration:.35 delay:0. options:UIViewAnimationOptionCurveEaseIn animations:^{
			label.alpha = (_available ? 1. : 0.5);
		} completion:^(BOOL finished) {
			_animating = NO;

			[self setNeedsLayout];
		}];
	}
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	[_chatPreviewLabels makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[_chatPreviewLabels removeAllObjects];

	self.name = @"";
	self.icon = nil;
	self.available = YES;

	_showsUserInMessagePreviews = YES;
	_maximumMessagePreviews = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQPreviewLinesCount"];
}

- (void) setHighlighted:(BOOL) highlighted animated:(BOOL) animated {
	[super setHighlighted:highlighted animated:animated];

	if (self.window.isFullscreen)
		return;

	[UIView animateWithDuration:(cq_shouldAnimate(animated) ? .3 : 0.) animations:^{
		CGFloat alpha = (_available || highlighted || self.selected ? 1. : 0.5);
		_nameLabel.alpha = alpha;
		_iconImageView.alpha = alpha;

		for (UILabel *label in _chatPreviewLabels)
			label.alpha = alpha;
	}];
}

- (void) _delayedDeselect {
	// Do nothing. This just messes up the selection if super handles it.
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	if (self.window.isFullscreen)
		return;

	[UIView animateWithDuration:(cq_shouldAnimate(animated) ? .3 : 0.) animations:^{
		CGFloat alpha = (_available || selected || self.highlighted ? 1. : 0.5);
		_nameLabel.alpha = alpha;
		_iconImageView.alpha = alpha;

		for (UILabel *label in _chatPreviewLabels)
			label.alpha = alpha;
	}];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[UIView animateWithDuration:(cq_shouldAnimate(animated) ? .3 : 0.) delay:0. options:(editing ? UIViewAnimationOptionCurveEaseIn : UIViewAnimationOptionCurveEaseOut) animations:^{
		[super setEditing:editing animated:animated];

		_unreadCountView.alpha = editing ? 0. : 1.;
	} completion:NULL];
}

- (void) layoutSubviewsWithAnimation:(BOOL) animated withDelay:(NSTimeInterval) animationDelay {
	[super layoutSubviews];

#define TOP_TEXT_MARGIN -1.
#define LEFT_MARGIN 10.
#define NO_ICON_LEFT_MARGIN 14.
#define RIGHT_MARGIN 10.
#define ICON_RIGHT_MARGIN 10.

	CGRect contentRect = self.contentView.bounds;

	CGRect frame = _unreadCountView.frame;
	frame.size = [_unreadCountView sizeThatFits:_unreadCountView.bounds.size];
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));

	if (self.showingDeleteConfirmation || self.showsReorderControl)
		frame.origin.x = self.bounds.size.width - contentRect.origin.x;
	else if (self.editing)
		frame.origin.x = contentRect.size.width - frame.size.width;
	else
		frame.origin.x = contentRect.size.width - frame.size.width - RIGHT_MARGIN;

	_unreadCountView.frame = frame;

	if (!_iconImageView.hidden) {
		frame = _iconImageView.frame;
		frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
		frame.origin.x = contentRect.origin.x + LEFT_MARGIN;
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
		_iconImageView.frame = frame;
	}

	if (!animated && _animating)
		return;

	frame = _nameLabel.frame;
	frame.size = [_nameLabel sizeThatFits:_nameLabel.bounds.size];

	CGFloat labelHeights = frame.size.height;

	for (UILabel *label in _chatPreviewLabels) {
		CGFloat height = label.frame.size.height;
		if (!height) {
			CGRect bounds = label.bounds;
			bounds.size = [label sizeThatFits:bounds.size];
			label.bounds = bounds;

			height = bounds.size.height;
		}

		labelHeights += height - LABEL_SPACING;
	}

	frame.origin.x = (_iconImageView.hidden ? NO_ICON_LEFT_MARGIN : CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN);
	frame.origin.y = round((contentRect.size.height / 2.) - (labelHeights / 2.)) + TOP_TEXT_MARGIN;
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	if (!self.editing && _unreadCountView.bounds.size.width)
		frame.size.width -= (contentRect.size.width - CGRectGetMinX(_unreadCountView.frame));

	[UIView animateWithDuration:(cq_shouldAnimate(animated) ? .25 : .0) animations:^{
		_nameLabel.frame = frame;

		CGFloat newVerticalOrigin = frame.origin.y + frame.size.height - LABEL_SPACING;
		for (UILabel *label in _chatPreviewLabels) {
			CGRect labelFrame = label.frame;

			BOOL disableAnimation = !labelFrame.origin.x;
			if (disableAnimation)
				[UIView setAnimationsEnabled:NO];

			labelFrame.origin.x = frame.origin.x;
			labelFrame.origin.y = newVerticalOrigin;
			labelFrame.size.width = frame.size.width;
			label.frame = labelFrame;

			if (disableAnimation)
				[UIView setAnimationsEnabled:YES];

			newVerticalOrigin = labelFrame.origin.y + labelFrame.size.height - LABEL_SPACING;
		}
	}];
}

- (void) layoutSubviews {
	[self layoutSubviewsWithAnimation:NO withDelay:0.];
}
@end

NS_ASSUME_NONNULL_END
