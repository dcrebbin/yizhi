//
//  ContentView.swift
//  yizhi
//
//  Created by Devon Crebbin on 17/12/2024.
//

import SwiftUI
import SwipeActions

// Helper extension
extension Calendar {
    fileprivate func startOfYear(for year: Int) -> Date {
        date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }
}

struct HalftonePattern: View {

    var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }

    let rows: Int = 10
    let columns: Int = 40

    var body: some View {
        GeometryReader { geometry in
            let dotSize = min(
                geometry.size.width / CGFloat(columns),
                geometry.size.height / CGFloat(rows))

            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { column in
                    Circle()
                        .fill(isDarkMode ? Color.white : Color.black)
                        .frame(
                            width: dotSize * getDotScale(row: row),
                            height: dotSize * getDotScale(row: row)
                        )
                        .position(
                            x: CGFloat(column) * (geometry.size.width / CGFloat(columns - 1)),
                            y: CGFloat(row) * (geometry.size.height / CGFloat(rows - 1))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 70)
        .background(Color.clear)
        .clipped()
    }

    private func getDotScale(row: Int) -> CGFloat {
        let progress = CGFloat(row) / CGFloat(rows)
        return 1.0 - progress
    }
}

struct ContentView: View {

    var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }

    struct Task: Decodable, Encodable {
        let name: String
        var completed: Bool
    }

    @State var newTask = ""

    var todaysDate: String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }

    var savedData: [String: [Task]] {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "data") as? [String: [Task]] ?? [:]
    }

    var savedTasks: [Task] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "tasks"),
            let decodedTasks = try? JSONDecoder().decode([Task].self, from: data)
        else {
            return []
        }
        return decodedTasks
    }

    @State var tasks: [Task] = []
    @State var contributionArray: [Double] = Array(repeating: 0.0, count: 365)

    func loadData() {
        print("Loading data")
        savedTasks.forEach { task in

            tasks.append(Task(name: task.name, completed: task.completed))
            print("Loaded task: \(task)")
        }
        calculateContribution()
    }

    func calculateContribution() {
        let defaults = UserDefaults.standard
        let data = defaults.object(forKey: "data") as? [String: [Task]] ?? [:]

        var newContributionArray = Array(repeating: 0.0, count: 365)

        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"

        var totalContribution = 0.0

        for dayOffset in 0..<365 {
            if let date = calendar.date(
                byAdding: .day, value: dayOffset,
                to: calendar.startOfYear(for: year))
            {
                let dateString = dateFormatter.string(from: date)

                if let tasks = data[dateString] {
                    let completedCount = tasks.filter(\.completed).count
                    let percentage =
                        tasks.isEmpty ? 0.0 : (Double(completedCount) / Double(tasks.count)) * 100.0

                    totalContribution += percentage
                    newContributionArray[dayOffset] = percentage
                }
            }
        }

        contributionArray = newContributionArray
        print("Average Daily Completion for \(year): \(totalContribution / 365.0)%")
    }

    // save data to user defaults
    func saveData() {
        print("Saving data")
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: "tasks")
        }
    }

    var body: some View {
        VStack(alignment: .center) {
            HalftonePattern()
            Text("一只 yīzhí")
                .font(.system(size: 40, design: .serif))
            ScrollView {
                VStack {
                    Text("今天 / \(todaysDate)")
                        .font(.system(size: 20))
                    ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                        SwipeView {
                            HStack {
                                Text(task.name).font(.system(size: 20, design: .serif))
                                Spacer()
                                Button(action: {
                                    tasks[index].completed.toggle()
                                }) {
                                    Image(
                                        systemName: tasks[index].completed
                                            ? "checkmark.square.fill" : "square"
                                    ).font(.system(size: 24))
                                        .foregroundColor(isDarkMode ? Color.white : Color.black)
                                }
                            }.padding(.horizontal, 20).padding(.vertical, 10)
                        } trailingActions: { context in
                            SwipeAction("Delete") {
                                tasks.remove(at: index)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(isDarkMode ? Color.black : Color.white)
                            .cornerRadius(0)
                            .background(isDarkMode ? Color.black : Color.white)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity / 2)
            HStack {
                TextField("Add a task", text: $newTask)
                    .font(.system(size: 20, design: .serif))
                    .textFieldStyle(.plain)
                    .padding()
                    .tint(isDarkMode ? Color.white : Color.black)
                    .background(isDarkMode ? Color.black : Color.white)
                Button(action: {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    print("Adding task: \(newTask)")
                    tasks.append(Task(name: newTask, completed: false))
                    saveData()
                    newTask = ""
                }) {
                    Text("ADD")
                        .foregroundColor(isDarkMode ? Color.white : Color.black)
                        .font(.system(size: 20, design: .serif))
                }
            }.padding(.horizontal, 25)
            VStack {
                Text("Consistency").font(.system(size: 20, design: .serif))
                ScrollView(.horizontal) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(35)), count: 7), spacing: 4) {
                        ForEach(0..<365) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(contributionColor(for: index))
                                .border(isDarkMode ? Color.white : Color.black, width: 1)
                                .frame(width: 35, height: 35)
                        }
                    }
                    .padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadData()
        }
    }

    private func contributionColor(for index: Int) -> Color {
        let intensity = contributionArray[index]
        return Color.black.opacity(intensity)
    }
}

#Preview {
    ContentView()
}
