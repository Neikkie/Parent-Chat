//
//  DefaultActivities.swift
//  Parent Chat
//
//  Created by Claude Code on 4/20/26.
//

import Foundation
import FirebaseFirestore

struct DefaultActivitiesSeeder {
    static let defaultActivities: [(name: String, title: String, description: String, latitude: Double, longitude: Double, locationName: String, ageGroups: [String], tags: [String], website: String?, contactInfo: String?)] = [
        (
            name: "New England Air Museum",
            title: "Connecticut's Aviation Museum",
            description: "The largest aviation museum in New England featuring over 100 aircraft and exhibits. Great for kids and families interested in aviation history, space exploration, and hands-on learning experiences.",
            latitude: 41.9339,
            longitude: -72.6828,
            locationName: "36 Perimeter Rd, Windsor Locks, CT 06096",
            ageGroups: ["All Ages", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Educational", "Museums", "STEM"],
            website: "https://www.neam.org",
            contactInfo: "(860) 623-3305"
        ),
        (
            name: "Connecticut Science Center",
            title: "Interactive Science Museum",
            description: "A state-of-the-art museum with over 165 hands-on exhibits exploring science, technology, engineering, and math. Features a 3D theater, planetarium, and interactive workshops perfect for curious minds.",
            latitude: 41.7658,
            longitude: -72.6734,
            locationName: "250 Columbus Blvd, Hartford, CT 06103",
            ageGroups: ["All Ages", "1-3 years", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Educational", "STEM", "Indoor", "Museums"],
            website: "https://www.ctsciencecenter.org",
            contactInfo: "(860) 724-3623"
        ),
        (
            name: "Beardsley Zoo",
            title: "Connecticut's Only Zoo",
            description: "Connecticut's only zoo featuring animals from around the world in natural habitats. Great for family outings with a carousel, picnic areas, and educational programs.",
            latitude: 41.1901,
            longitude: -73.2132,
            locationName: "1875 Noble Ave, Bridgeport, CT 06610",
            ageGroups: ["All Ages", "0-1 years", "1-3 years", "3-5 years", "5-12 years"],
            tags: ["Outdoor", "Animals", "Educational"],
            website: "https://www.beardsleyzoo.org",
            contactInfo: "(203) 394-6565"
        ),
        (
            name: "Mystic Aquarium",
            title: "Marine Life Discovery Center",
            description: "World-class aquarium featuring beluga whales, African penguins, sea lions, and more. Interactive touch tanks and 4D theater experiences make learning about ocean life exciting for all ages.",
            latitude: 41.3614,
            longitude: -71.9656,
            locationName: "55 Coogan Blvd, Mystic, CT 06355",
            ageGroups: ["All Ages", "0-1 years", "1-3 years", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Educational", "Animals", "Indoor", "Outdoor"],
            website: "https://www.mysticaquarium.org",
            contactInfo: "(860) 572-5955"
        ),
        (
            name: "Lake Compounce",
            title: "America's Oldest Amusement Park",
            description: "Family-friendly amusement park with thrilling rides, water park, and entertainment. Perfect for a full day of family fun with rides suitable for all ages.",
            latitude: 41.5981,
            longitude: -72.8973,
            locationName: "186 Enterprise Dr, Bristol, CT 06010",
            ageGroups: ["All Ages", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Outdoor", "Entertainment", "Sports"],
            website: "https://www.lakecompounce.com",
            contactInfo: "(860) 583-3300"
        ),
        (
            name: "Children's Museum of Connecticut",
            title: "Hands-On Learning for Young Children",
            description: "Interactive museum designed for children ages 0-10 with exhibits focused on science, wildlife, the arts, and healthy living. Features a planetarium and outdoor learning garden.",
            latitude: 41.2282,
            longitude: -73.1221,
            locationName: "950 Trumbull St, West Hartford, CT 06110",
            ageGroups: ["0-1 years", "1-3 years", "3-5 years", "5-12 years"],
            tags: ["Educational", "Indoor", "Arts & Crafts", "STEM"],
            website: "https://www.thechildrensmuseumct.org",
            contactInfo: "(860) 231-2824"
        ),
        (
            name: "Wickham Park",
            title: "Beautiful Gardens and Recreation",
            description: "250-acre park featuring oriental gardens, nature trails, playgrounds, sports fields, and picnic areas. Great for outdoor family activities year-round.",
            latitude: 41.7820,
            longitude: -72.5145,
            locationName: "1329 Middle Turnpike W, Manchester, CT 06040",
            ageGroups: ["All Ages", "0-1 years", "1-3 years", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Outdoor", "Nature", "Sports", "Free"],
            website: "https://www.wickhampark.org",
            contactInfo: "(860) 528-0856"
        ),
        (
            name: "Stepping Stones Museum for Children",
            title: "Interactive Learning Museum",
            description: "Award-winning children's museum with hands-on exhibits about science, technology, arts, and culture. Features Healthyville, Waterscape, and Energy Lab exhibits.",
            latitude: 41.0662,
            longitude: -73.5387,
            locationName: "303 West Ave, Norwalk, CT 06850",
            ageGroups: ["0-1 years", "1-3 years", "3-5 years", "5-12 years"],
            tags: ["Educational", "Indoor", "STEM", "Arts & Crafts"],
            website: "https://www.steppingstonesmuseum.org",
            contactInfo: "(203) 899-0606"
        ),
        (
            name: "Dinosaur State Park",
            title: "Prehistoric Footprints & Nature Trails",
            description: "See one of the largest dinosaur track sites in North America! Features 500 tracks dating back 200 million years, along with nature trails and a hands-on discovery center.",
            latitude: 41.6206,
            longitude: -72.6506,
            locationName: "400 West St, Rocky Hill, CT 06067",
            ageGroups: ["All Ages", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Educational", "Outdoor", "Nature", "Museums"],
            website: "https://portal.ct.gov/DEEP/State-Parks/Parks/Dinosaur-State-Park",
            contactInfo: "(860) 529-8423"
        ),
        (
            name: "Bushnell Park",
            title: "Hartford's Historic Downtown Park",
            description: "Beautiful 50-acre urban park featuring a vintage carousel, playgrounds, walking paths, and seasonal events. Perfect for picnics and outdoor play in the heart of Hartford.",
            latitude: 41.7659,
            longitude: -72.6823,
            locationName: "166 Capitol Ave, Hartford, CT 06106",
            ageGroups: ["All Ages", "0-1 years", "1-3 years", "3-5 years", "5-12 years", "13-18 years"],
            tags: ["Outdoor", "Free", "Nature", "Entertainment"],
            website: "https://www.bushnellpark.org",
            contactInfo: "(860) 232-6710"
        )
    ]
    
    @MainActor
    static func seedActivitiesIfNeeded() async {
        let userDefaults = UserDefaults.standard
        let hasSeededKey = "hasSeededDefaultActivities_v1"
        
        // Check if we've already seeded activities
        guard !userDefaults.bool(forKey: hasSeededKey) else {
            print("✅ Default activities already seeded")
            return
        }
        
        print("🌱 Seeding default Connecticut activities...")
        
        for activity in defaultActivities {
            do {
                try await FirestoreManager.shared.createActivity(
                    name: activity.name,
                    title: activity.title,
                    description: activity.description,
                    location: PostLocation(
                        name: activity.locationName,
                        latitude: activity.latitude,
                        longitude: activity.longitude
                    ),
                    ageGroups: activity.ageGroups,
                    tags: activity.tags,
                    userId: "system",
                    userName: "Parent Chat",
                    imageUrls: nil,
                    website: activity.website,
                    contactInfo: activity.contactInfo
                )
                print("✅ Added: \(activity.name)")
            } catch {
                print("❌ Failed to add \(activity.name): \(error.localizedDescription)")
            }
        }
        
        // Mark as seeded
        userDefaults.set(true, forKey: hasSeededKey)
        print("🎉 Finished seeding default activities!")
    }
}
