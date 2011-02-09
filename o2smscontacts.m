/*
	Copyright (c) 2011
	Conor McDermottroe.  All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions
	are met:
	1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
	2. Redistributions in binary form must reproduce the above copyright
	   notice, this list of conditions and the following disclaimer in the
	   documentation and/or other materials provided with the distribution.
	3. Neither the name of the author nor the names of any contributors to
	   the software may be used to endorse or promote products derived from
	   this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
	A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
	HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
	OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import <AddressBook/ABAddressBook.h>
#import <AddressBook/ABMultiValue.h>
#import <AddressBook/ABPerson.h>
#import <AddressBook/ABRecord.h>

/* A quick hack to generate an aliases file for o2sms
 * (http://o2sms.sourceforge.net/) from the Apple Address Book.
 */
int main(int argc, const char* argv[]) {
	// The preferred ordering for fetching phones
	NSString* phoneOrder[] = {
		kABPhoneiPhoneLabel,
		kABPhoneMobileLabel,
		kABPhoneHomeLabel,
		kABPhoneWorkLabel,
		kABPhoneMainLabel,
		kABPhonePagerLabel,
		kABPhoneHomeFAXLabel,
		kABPhoneWorkFAXLabel,
		nil
	};

	// Create a dictionary to store a mapping from name to phone number.
	NSMutableDictionary* allNumbers = [[NSMutableDictionary alloc] initWithCapacity:100];

	// Get the address book.
	ABAddressBook* addressBook = [ABAddressBook sharedAddressBook];

	// Find all the people with a non-nil phone property
	ABSearchElement* find = [ABPerson
		searchElementForProperty: kABPhoneProperty
						   label: nil
							 key: nil
						   value: nil
					  comparison: kABNotEqual];
	NSArray* results = [addressBook recordsMatchingSearchElement: find];

	// Go through the results
	if ([results count] > 0) {
		ABRecord* person;
		for (person in results) {
			// Construct the display name for the person.
			NSString* name = nil;
			NSString* fname = [person valueForProperty:kABFirstNameProperty];
			NSString* sname = [person valueForProperty:kABLastNameProperty];
			NSString* cname = [person valueForProperty:kABOrganizationProperty];
			if (fname == nil && sname == nil) {
				if (cname != nil) {
					name = cname;
				}
			} else {
				if (fname != nil && sname != nil) {
					name = [[fname stringByAppendingString:@" "] stringByAppendingString:sname];
				} else if (fname != nil) {
					name = fname;
				} else if (sname != nil) {
					name = sname;
				}
			}

			// Lower-case the name then force it to ASCII
			name = [name lowercaseString];
			NSData* data = [name dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: true];

			// Force it into [a-z_], coalesce runs of _ and strip _ from start
			// and end of name.
			const char* s = [data bytes];
			char buffer[256];
			int bufidx = 0;
			for (int i = 0; i < strlen(s); i++) {
				if (s[i] <= 0) {
					buffer[bufidx] = 0;
					bufidx++;
					break;
				} else if (s[i] == '\'') {
					// Skip
				} else if (!(s[i] >= 'a' && s[i] <= 'z')) {
					if (!(bufidx >= 1 && buffer[bufidx - 1] == '_')) {
						buffer[bufidx] = '_';
						bufidx++;
					}
				} else {
					buffer[bufidx] = s[i];
					bufidx++;
				}
			}
			buffer[bufidx] = 0;
			while (bufidx >= 1 && buffer[bufidx - 1] == '_') {
				buffer[bufidx - 1] = 0;
				bufidx--;
			}

			// Put the name back in an NSString
			name = [[NSString alloc] initWithBytes:buffer length:sizeof(buffer) encoding:NSASCIIStringEncoding];

			// Get the phone number
			ABMultiValue* phones = [person valueForProperty:kABPhoneProperty];
			NSString* phone = nil;
			if ([phones count] > 0) {
				int i = 0;
				while (phoneOrder[i] != nil) {
					for (int j = 0; j < [phones count]; j++) {
						if ([phoneOrder[i] isEqualToString:[phones labelAtIndex:j]]) {
							phone = [phones valueAtIndex:j];
							break;
						}
					}
					if (phone != nil) {
						break;
					}
					i++;
				}
			}

			if (phone != nil) {
				// Convert the number into the correct format.
				data = [phone dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: true];
				const char* p = [data bytes];
				bufidx = 0;
				for (int i = 0; i < strlen(p); i++) {
					if (p[i] == '+') {
						buffer[bufidx++] = '0';
						buffer[bufidx++] = '0';
					} else if (p[i] >= '0' && p[i] <= '9') {
						buffer[bufidx++] = p[i];
					}
				}
				buffer[bufidx++] = 0;
				buffer[bufidx++] = 0;
				if (sizeof(buffer) > 0) {
					phone = [[NSString alloc] initWithBytes:buffer length:sizeof(buffer) encoding:NSASCIIStringEncoding];
				}

				// Put the name -> number mapping in the dictionary
				[allNumbers setValue:phone forKey:name];
			}
		}
	}

	// Once we get to this point, we have a dictionary - allNumbers - which has
	// a mapping of names to numbers. We need to sort it, then output it.
	NSMutableArray* sortedKeys = [NSMutableArray arrayWithArray: [allNumbers allKeys]];
	[sortedKeys sortUsingSelector:@selector(compare:)];
	for (NSString* key in sortedKeys) {
		printf(
			"alias %s %s\n",
			[key UTF8String],
			[[allNumbers objectForKey:key] UTF8String]
		);
	}

	return 0;
}
