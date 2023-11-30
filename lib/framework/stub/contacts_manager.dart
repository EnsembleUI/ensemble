import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/foundation.dart';

typedef ContactSuccessCallback = void Function(List<Contact> contacts);
typedef ContactErrorCallback = void Function(dynamic);

abstract class ContactManager {
  void getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError);

  Future<bool> requestPermission();
}

class ContactManagerStub extends ContactManager {
  @override
  void getPhoneContacts(
      ContactSuccessCallback onSuccess, ContactErrorCallback onError) {
    throw ConfigError(
        "Phone Contact Service is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<bool> requestPermission() {
    throw ConfigError(
        "Phone Contact Service is not enabled. Please review the Ensemble documentation.");
  }
}

class Contact {
  String id;
  String displayName;
  Uint8List? thumbnail;
  Uint8List? photo;

  Uint8List? get photoOrThumbnail => photo ?? thumbnail;
  bool isStarred;
  Name name;
  List<Phone> phones;
  List<Email> emails;
  List<Address> addresses;
  List<Organization> organizations;
  Organization? organization;
  List<Website> websites;
  bool thumbnailFetched = true;
  bool photoFetched = true;
  bool isUnified = true;
  bool propertiesFetched = true;

  Contact({
    this.id = '',
    this.displayName = '',
    this.thumbnail,
    this.photo,
    this.isStarred = false,
    Name? name,
    List<Phone>? phones,
    List<Email>? emails,
    List<Address>? addresses,
    List<Organization>? organizations,
    List<Website>? websites,
  })  : name = name ?? Name(),
        phones = phones ?? <Phone>[],
        emails = emails ?? <Email>[],
        addresses = addresses ?? <Address>[],
        organizations = organizations ?? <Organization>[],
        organization = organizations != null && organizations.isNotEmpty
            ? organizations[0]
            : null,
        websites = websites ?? <Website>[];

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: (json['id'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? '',
        thumbnail: json['thumbnail'] as Uint8List?,
        photo: json['photo'] as Uint8List?,
        isStarred: (json['isStarred'] as bool?) ?? false,
        name: Name.fromJson(Map<String, dynamic>.from(json['name'] ?? {})),
        phones: ((json['phones'] as List?) ?? [])
            .map((x) => Phone.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        emails: ((json['emails'] as List?) ?? [])
            .map((x) => Email.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        addresses: ((json['addresses'] as List?) ?? [])
            .map((x) => Address.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        organizations: ((json['organizations'] as List?) ?? [])
            .map((x) => Organization.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        websites: ((json['websites'] as List?) ?? [])
            .map((x) => Website.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );

  Map<String, dynamic> toJson({
    bool withThumbnail = true,
    bool withPhoto = true,
  }) =>
      Map<String, dynamic>.from({
        'id': id,
        'displayName': displayName,
        'thumbnail': withThumbnail ? thumbnail : null,
        'photo': withPhoto ? photo : null,
        'isStarred': isStarred,
        'name': name.toJson(),
        'phones': phones.map((x) => x.toJson()).toList(),
        'phone': phones.isNotEmpty ? phones[0].number : '', // first phone
        'emails': emails.map((x) => x.toJson()).toList(),
        'email': emails.isNotEmpty ? emails[0].address : '', // first email
        'addresses': addresses.map((x) => x.toJson()).toList(),
        'organizations': organizations.map((x) => x.toJson()).toList(),
        'organization': organization,
        'websites': websites.map((x) => x.toJson()).toList(),
      });
}

class Name {
  String first;
  String last;
  String middle;
  String prefix;
  String suffix;
  String nickname;
  String firstPhonetic;
  String lastPhonetic;
  String middlePhonetic;

  Name({
    this.first = '',
    this.last = '',
    this.middle = '',
    this.prefix = '',
    this.suffix = '',
    this.nickname = '',
    this.firstPhonetic = '',
    this.lastPhonetic = '',
    this.middlePhonetic = '',
  });

  factory Name.fromJson(Map<String, dynamic> json) => Name(
        first: (json['first'] as String?) ?? '',
        last: (json['last'] as String?) ?? '',
        middle: (json['middle'] as String?) ?? '',
        prefix: (json['prefix'] as String?) ?? '',
        suffix: (json['suffix'] as String?) ?? '',
        nickname: (json['nickname'] as String?) ?? '',
        firstPhonetic: (json['firstPhonetic'] as String?) ?? '',
        lastPhonetic: (json['lastPhonetic'] as String?) ?? '',
        middlePhonetic: (json['middlePhonetic'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'first': first,
        'last': last,
        'middle': middle,
        'prefix': prefix,
        'suffix': suffix,
        'nickname': nickname,
        'firstPhonetic': firstPhonetic,
        'lastPhonetic': lastPhonetic,
        'middlePhonetic': middlePhonetic,
      };
}

class Website {
  String url;

  WebsiteLabel label;

  String customLabel;

  Website(this.url,
      {this.label = WebsiteLabel.homepage, this.customLabel = ''});

  factory Website.fromJson(Map<String, dynamic> json) => Website(
        (json['url'] as String?) ?? '',
        label: _stringToWebsiteLabel[json['label'] as String? ?? ''] ??
            WebsiteLabel.homepage,
        customLabel: (json['customLabel'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'label': _websiteLabelToString[label],
        'customLabel': customLabel,
      };
}

enum WebsiteLabel {
  blog,
  ftp,
  home,
  homepage,
  profile,
  school,
  work,
  other,
  custom,
}

final _websiteLabelToString = {
  WebsiteLabel.blog: 'blog',
  WebsiteLabel.ftp: 'ftp',
  WebsiteLabel.home: 'home',
  WebsiteLabel.homepage: 'homepage',
  WebsiteLabel.profile: 'profile',
  WebsiteLabel.school: 'school',
  WebsiteLabel.work: 'work',
  WebsiteLabel.other: 'other',
  WebsiteLabel.custom: 'custom',
};

final _stringToWebsiteLabel = {
  'blog': WebsiteLabel.blog,
  'ftp': WebsiteLabel.ftp,
  'home': WebsiteLabel.home,
  'homepage': WebsiteLabel.homepage,
  'profile': WebsiteLabel.profile,
  'school': WebsiteLabel.school,
  'work': WebsiteLabel.work,
  'other': WebsiteLabel.other,
  'custom': WebsiteLabel.custom,
};

class Email {
  String address;

  EmailLabel label;

  String customLabel;

  bool isPrimary;

  Email(
    this.address, {
    this.label = EmailLabel.home,
    this.customLabel = '',
    this.isPrimary = false,
  });

  factory Email.fromJson(Map<String, dynamic> json) => Email(
        (json['address'] as String?) ?? '',
        label: _stringToEmailLabel[json['label'] as String? ?? ''] ??
            EmailLabel.home,
        customLabel: (json['customLabel'] as String?) ?? '',
        isPrimary: (json['isPrimary'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'address': address,
        'label': _emailLabelToString[label],
        'customLabel': customLabel,
        'isPrimary': isPrimary,
      };
}

enum EmailLabel {
  home,
  iCloud,
  mobile,
  school,
  work,
  other,
  custom,
}

final _emailLabelToString = {
  EmailLabel.home: 'home',
  EmailLabel.iCloud: 'iCloud',
  EmailLabel.mobile: 'mobile',
  EmailLabel.school: 'school',
  EmailLabel.work: 'work',
  EmailLabel.other: 'other',
  EmailLabel.custom: 'custom',
};

final _stringToEmailLabel = {
  'home': EmailLabel.home,
  'iCloud': EmailLabel.iCloud,
  'mobile': EmailLabel.mobile,
  'school': EmailLabel.school,
  'work': EmailLabel.work,
  'other': EmailLabel.other,
  'custom': EmailLabel.custom,
};

class Phone {
  String number;
  String normalizedNumber;
  PhoneLabel label;
  String customLabel;
  bool isPrimary;

  Phone(
    this.number, {
    this.normalizedNumber = '',
    this.label = PhoneLabel.mobile,
    this.customLabel = '',
    this.isPrimary = false,
  });

  factory Phone.fromJson(Map<String, dynamic> json) => Phone(
        (json['number'] as String?) ?? '',
        normalizedNumber: (json['normalizedNumber'] as String?) ?? '',
        label: _stringToPhoneLabel[json['label'] as String? ?? ''] ??
            PhoneLabel.mobile,
        customLabel: (json['customLabel'] as String?) ?? '',
        isPrimary: (json['isPrimary'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'number': number,
        'normalizedNumber': normalizedNumber,
        'label': _phoneLabelToString[label],
        'customLabel': customLabel,
        'isPrimary': isPrimary,
      };
}

enum PhoneLabel {
  assistant,
  callback,
  car,
  companyMain,
  faxHome,
  faxOther,
  faxWork,
  home,
  iPhone,
  isdn,
  main,
  mms,
  mobile,
  pager,
  radio,
  school,
  telex,
  ttyTtd,
  work,
  workMobile,
  workPager,
  other,
  custom,
}

final _phoneLabelToString = {
  PhoneLabel.assistant: 'assistant',
  PhoneLabel.callback: 'callback',
  PhoneLabel.car: 'car',
  PhoneLabel.companyMain: 'companyMain',
  PhoneLabel.faxHome: 'faxHome',
  PhoneLabel.faxOther: 'faxOther',
  PhoneLabel.faxWork: 'faxWork',
  PhoneLabel.home: 'home',
  PhoneLabel.iPhone: 'iPhone',
  PhoneLabel.isdn: 'isdn',
  PhoneLabel.main: 'main',
  PhoneLabel.mms: 'mms',
  PhoneLabel.mobile: 'mobile',
  PhoneLabel.pager: 'pager',
  PhoneLabel.radio: 'radio',
  PhoneLabel.school: 'school',
  PhoneLabel.telex: 'telex',
  PhoneLabel.ttyTtd: 'ttyTtd',
  PhoneLabel.work: 'work',
  PhoneLabel.workMobile: 'workMobile',
  PhoneLabel.workPager: 'workPager',
  PhoneLabel.other: 'other',
  PhoneLabel.custom: 'custom',
};

final _stringToPhoneLabel = {
  'assistant': PhoneLabel.assistant,
  'callback': PhoneLabel.callback,
  'car': PhoneLabel.car,
  'companyMain': PhoneLabel.companyMain,
  'faxHome': PhoneLabel.faxHome,
  'faxOther': PhoneLabel.faxOther,
  'faxWork': PhoneLabel.faxWork,
  'home': PhoneLabel.home,
  'iPhone': PhoneLabel.iPhone,
  'isdn': PhoneLabel.isdn,
  'main': PhoneLabel.main,
  'mms': PhoneLabel.mms,
  'mobile': PhoneLabel.mobile,
  'pager': PhoneLabel.pager,
  'radio': PhoneLabel.radio,
  'school': PhoneLabel.school,
  'telex': PhoneLabel.telex,
  'ttyTtd': PhoneLabel.ttyTtd,
  'work': PhoneLabel.work,
  'workMobile': PhoneLabel.workMobile,
  'workPager': PhoneLabel.workPager,
  'other': PhoneLabel.other,
  'custom': PhoneLabel.custom,
};

class Organization {
  String company;
  String title;
  String department;
  String jobDescription;
  String symbol;
  String phoneticName;
  String officeLocation;

  Organization({
    this.company = '',
    this.title = '',
    this.department = '',
    this.jobDescription = '',
    this.symbol = '',
    this.phoneticName = '',
    this.officeLocation = '',
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        company: (json['company'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        department: (json['department'] as String?) ?? '',
        jobDescription: (json['jobDescription'] as String?) ?? '',
        symbol: (json['symbol'] as String?) ?? '',
        phoneticName: (json['phoneticName'] as String?) ?? '',
        officeLocation: (json['officeLocation'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'company': company,
        'title': title,
        'department': department,
        'jobDescription': jobDescription,
        'symbol': symbol,
        'phoneticName': phoneticName,
        'officeLocation': officeLocation,
      };
}

class Address {
  String address;
  AddressLabel label;
  String customLabel;
  String street;
  String pobox;
  String neighborhood;
  String city;
  String state;
  String postalCode;
  String country;
  String isoCountry;
  String subAdminArea;
  String subLocality;

  Address(
    this.address, {
    this.label = AddressLabel.home,
    this.customLabel = '',
    this.street = '',
    this.pobox = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.isoCountry = '',
    this.subAdminArea = '',
    this.subLocality = '',
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        (json['address'] as String?) ?? '',
        label: _stringToAddressLabel[json['label'] as String? ?? ''] ??
            AddressLabel.home,
        customLabel: (json['customLabel'] as String?) ?? '',
        street: (json['street'] as String?) ?? '',
        pobox: (json['pobox'] as String?) ?? '',
        neighborhood: (json['neighborhood'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        state: (json['state'] as String?) ?? '',
        postalCode: (json['postalCode'] as String?) ?? '',
        country: (json['country'] as String?) ?? '',
        isoCountry: (json['isoCountry'] as String?) ?? '',
        subAdminArea: (json['subAdminArea'] as String?) ?? '',
        subLocality: (json['subLocality'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'address': address,
        'label': _addressLabelToString[label],
        'customLabel': customLabel,
        'street': street,
        'pobox': pobox,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'country': country,
        'isoCountry': isoCountry,
        'subAdminArea': subAdminArea,
        'subLocality': subLocality,
      };
}

enum AddressLabel {
  home,
  school,
  work,
  other,
  custom,
}

final _addressLabelToString = {
  AddressLabel.home: 'home',
  AddressLabel.school: 'school',
  AddressLabel.work: 'work',
  AddressLabel.other: 'other',
  AddressLabel.custom: 'custom',
};

final _stringToAddressLabel = {
  'home': AddressLabel.home,
  'school': AddressLabel.school,
  'work': AddressLabel.work,
  'other': AddressLabel.other,
  'custom': AddressLabel.custom,
};
