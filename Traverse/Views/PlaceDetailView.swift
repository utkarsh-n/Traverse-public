//
//  PlaceDetailView.swift
//  Traverse
//

import SwiftUI
import MapKit
import SwiftData

struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var place: PlaceVisit
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var showingCategoryPicker = false
    
    @Query private var allPlaces: [PlaceVisit]
    
    private var visitCount: Int {
        // Count visits within clustering distance (~80m)
        allPlaces.filter { otherPlace in
            place.distance(to: otherPlace.coordinate) < 80
        }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Map
                    mapView
                        .frame(height: 200)
                    
                    // Place info
                    placeInfoCard
                        .padding(20)
                }
            }
            .background(ColorTheme.background)
            .navigationTitle("Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            categoryPickerSheet
        }
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: place.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Annotation(place.displayName, coordinate: place.coordinate) {
                ZStack {
                    Circle()
                        .fill(place.category?.color ?? ColorTheme.accent)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: place.category?.icon ?? "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }
    
    // MARK: - Place Info Card
    
    private var placeInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Place name (editable)
            HStack {
                if isEditingName {
                    TextField("Place name", text: $editedName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ColorTheme.primaryText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(ColorTheme.secondaryBackground)
                        .cornerRadius(8)
                        .onSubmit {
                            saveName()
                        }
                    
                    Button("Save") {
                        saveName()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTheme.accent)
                } else {
                    Text(place.displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ColorTheme.primaryText)
                    
                    Spacer()
                    
                    Button {
                        editedName = place.name ?? ""
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTheme.secondaryText)
                    }
                }
            }
            
            // Address
            if let address = place.address, !address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    Text(address)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.secondaryText)
                }
            }
            
            Divider()
                .background(ColorTheme.secondaryText.opacity(0.3))
            
            // Category
            HStack {
                Text("Category")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTheme.secondaryText)
                
                Spacer()
                
                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack(spacing: 6) {
                        if let category = place.category {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.displayName)
                        } else {
                            Text("Set category")
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(place.category?.color ?? ColorTheme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill((place.category?.color ?? ColorTheme.secondaryText).opacity(0.2))
                    }
                }
            }
            
            Divider()
                .background(ColorTheme.secondaryText.opacity(0.3))
            
            // Time spent
            VStack(alignment: .leading, spacing: 8) {
                Text("Time spent")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTheme.secondaryText)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arrived")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTheme.secondaryText)
                        Text(place.arrivalTime.timeString)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ColorTheme.primaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(ColorTheme.secondaryText)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Departed")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTheme.secondaryText)
                        
                        if place.isOngoing {
                            Text("Still here")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ColorTheme.accent)
                        } else if let departure = place.departureTime {
                            Text(departure.timeString)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ColorTheme.primaryText)
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Text(place.durationFormatted)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(ColorTheme.primaryText)
                    Spacer()
                }
                .padding(.top, 8)
            }
            
            Divider()
                .background(ColorTheme.secondaryText.opacity(0.3))
            
            // Visit count
            HStack {
                Image(systemName: "repeat")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTheme.secondaryText)
                
                Text("You've been here \(visitCount) \(visitCount == 1 ? "time" : "times")")
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTheme.secondaryText)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        }
    }
    
    // MARK: - Category Picker
    
    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    Button {
                        place.category = category
                        showingCategoryPicker = false
                        try? modelContext.save()
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(category.color)
                                .frame(width: 24)
                            
                            Text(category.displayName)
                                .foregroundStyle(ColorTheme.primaryText)
                            
                            Spacer()
                            
                            if place.category == category {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(category.color)
                            }
                        }
                    }
                    .listRowBackground(ColorTheme.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorTheme.background)
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingCategoryPicker = false
                    }
                    .foregroundStyle(ColorTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Actions
    
    private func saveName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            place.name = trimmedName
            place.isUserLabeled = true
            try? modelContext.save()
        }
        isEditingName = false
    }
}

// MARK: - PlaceCategory Color Extension

extension PlaceCategory {
    var color: Color {
        switch self {
        case .home: return ColorTheme.home
        case .work: return ColorTheme.work
        case .food: return ColorTheme.food
        case .shop: return ColorTheme.shop
        case .gym: return ColorTheme.running
        case .entertainment: return ColorTheme.cycling
        case .transit: return ColorTheme.vehicle
        case .other: return ColorTheme.stationary
        }
    }
}

// MARK: - Preview

#Preview {
    PlaceDetailView(
        place: PlaceVisit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivalTime: Date().addingTimeInterval(-7200),
            departureTime: Date().addingTimeInterval(-3600),
            name: "Coffee Shop",
            address: "123 Main St, San Francisco",
            category: .food
        )
    )
    .modelContainer(for: PlaceVisit.self, inMemory: true)
}
