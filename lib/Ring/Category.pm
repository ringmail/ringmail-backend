package Ring::Category;
use strict;
use warnings;

use vars qw(@category_list %category_hash);

BEGIN: {
	our @category_list = (
		'Food & Dining',
		'Shopping',
		'Personal Services',
		'Automotive',
		'Entertainment',
		'Home & Garden',
		'Financial Services',
		'Travel',
		'Real Estate',
		'Health & Medicine',
		'Professional Services',
		'Community & Gov.',
	);

	our %category_hash = (
		'Food & Dining' => {
			'factual' => 'Food and Dining',
			'icon' => 'food_dining_btn.png',
		},
		'Shopping' => {
			'factual' => 'Retail',
			'icon' => 'shopping_btn.png',
		},
		'Personal Services' => {
			'factual' => 'Personal Care',
			'icon' => 'personal_services_btn.png',
		},
		'Automotive' => {
			'factual' => 'Automotive',
			'icon' => 'automotive_btn.png',
		},
		'Entertainment' => {
			'factual' => 'Entertainment',
			'icon' => 'entertainment_btn.png',
		},
		'Home & Garden' => {
			'factual' => 'Home Improvement',
			'icon' => 'home_garden_btn.png',
		},
		'Financial Services' => {
			'factual' => 'Financial',
			'icon' => 'financial_btn.png',
		},
		'Travel' => {
			'factual' => 'Travel',
			'icon' => 'travel_btn.png',
		},
		'Real Estate' => {
			'factual' => 'Real Estate',
			'icon' => 'realestate_btn.png',
		},
		'Health & Medicine' => {
			'factual' => 'Healthcare',
			'icon' => 'health_btn.png',
		},
		'Professional Services' => {
			'factual' => 'Legal',
			'icon' => 'professional_btn.png',
		},
		'Community & Gov.' => {
			'factual' => 'Community and Government',
			'icon' => 'gov_btn.png',
		},
	);
}

return 1;

