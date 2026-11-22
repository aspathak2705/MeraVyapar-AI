import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/market_intelligence/domain/market_event_model.dart';

void main() {
  group('MarketEventModel and MarketSourceModel Tests', () {
    test('parses rich source and event models with price, rating, location', () {
      final json = {
        'id': 'ev-123',
        'event_type': 'COMMODITY_PRICE_MOVEMENT',
        'title': 'Wholesale Rice Rate',
        'summary': 'Rice rates in Pune APMC',
        'geography': 'Pune',
        'sector': 'Grains',
        'affected_domains': ['INVENTORY', 'EXPENSE'],
        'occurred_at': '2026-11-22T10:00:00Z',
        'price': '₹2,100',
        'rating': 4.5,
        'reviews': 80,
        'location': 'Pune Market Yard',
        'engine': 'google_shopping',
        'evidence_nature': 'OBSERVED_ONLINE_LISTING',
        'source': {
          'id': 'src-123',
          'provider_name': 'SerpApi',
          'source_name': 'Google Shopping',
          'source_url': 'https://shopping.example/rice',
          'title': 'Wholesale Rice',
          'published_at': '2026-11-22T09:30:00Z',
          'price': '₹2,100',
          'rating': 4.5,
          'reviews': 80,
          'location': 'Pune Market Yard',
          'engine': 'google_shopping',
          'evidence_nature': 'OBSERVED_ONLINE_LISTING',
          'verification_status': 'OBSERVED_ONLINE_LISTING_PRICE',
        },
      };

      final event = MarketEventModel.fromJson(json);

      expect(event.id, equals('ev-123'));
      expect(event.title, equals('Wholesale Rice Rate'));
      expect(event.price, equals('₹2,100'));
      expect(event.rating, equals(4.5));
      expect(event.reviews, equals(80));
      expect(event.location, equals('Pune Market Yard'));
      expect(event.engine, equals('google_shopping'));
      expect(event.evidenceNature, equals('OBSERVED_ONLINE_LISTING'));
      expect(event.source?.sourceName, equals('Google Shopping'));
      expect(event.source?.price, equals('₹2,100'));
      expect(event.source?.verificationStatus, equals('OBSERVED_ONLINE_LISTING_PRICE'));
    });

    test('handles relative date strings and unsupported formats deterministically', () {
      final jsonRelative = {
        'id': 'ev-456',
        'event_type': 'SUPPLY_CHAIN_EVENT',
        'title': 'Supplier Notice',
        'summary': 'Notice from mandi',
        'affected_domains': ['EXPENSE'],
        'occurred_at': '2 hours ago',
        'source': {
          'id': 'src-456',
          'provider_name': 'SerpApi',
          'source_name': 'Google Maps',
          'source_url': 'https://maps.example/mandi',
          'title': 'Mandi Yard',
          'published_at': 'Yesterday',
        },
      };

      final event = MarketEventModel.fromJson(jsonRelative);

      expect(event.id, equals('ev-456'));
      expect(event.occurredAt, isNotNull);
      // Ensure "2 hours ago" is earlier than now and not fabricated to current minute
      final diffMinutes = DateTime.now().toUtc().difference(event.occurredAt!).inMinutes;
      expect(diffMinutes, inInclusiveRange(115, 125));

      expect(event.source?.publishedAt, isNotNull);
      final diffDays = DateTime.now().toUtc().difference(event.source!.publishedAt!).inHours;
      expect(diffDays, inInclusiveRange(23, 26));

      // Test completely unsupported format: must return null without fabricating a fake date
      final jsonUnsupported = {
        'id': 'ev-789',
        'event_type': 'OTHER',
        'title': 'Historic Report',
        'summary': 'Summary',
        'affected_domains': [],
        'occurred_at': 'sometime in early spring 2022',
        'source': {
          'id': 'src-789',
          'provider_name': 'SerpApi',
          'source_name': 'Google Search',
          'source_url': 'https://example.com',
          'title': 'Report',
          'published_at': 'unknown vintage period',
        },
      };

      final unsuppEvent = MarketEventModel.fromJson(jsonUnsupported);
      expect(unsuppEvent.occurredAt, isNull);
      expect(unsuppEvent.rawOccurredAt, equals('sometime in early spring 2022'));
      expect(unsuppEvent.source?.publishedAt, isNull);
      expect(unsuppEvent.source?.rawPublishedAt, equals('unknown vintage period'));
    });
  });
}
