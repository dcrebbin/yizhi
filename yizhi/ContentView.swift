//
//  ContentView.swift
//  yizhi
//
//  Created by Devon Crebbin on 17/12/2024.
//

import SwiftUI
import SwipeActions

struct ContentView: View {

    struct Task {
        let name: String
        var completed: Bool
    }

    @State var tasks = [
        Task(name: "task1", completed: false),
        Task(name: "task2", completed: false),
        Task(name: "task3", completed: false),
    ]

    @State var newTask = ""

    var body: some View {
        VStack(alignment: .center) {
            Text("一只 yīzhí").font(.system(size: 40))
            ScrollView {
                Text("今天 / today").font(.system(size: 20))
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    SwipeView {
                        HStack {
                            Text(task.name)
                            Spacer()
                            Button(action: {
                                tasks[index].completed.toggle()
                            }) {
                                Image(
                                    systemName: tasks[index].completed
                                        ? "checkmark.square.fill" : "square"
                                ).font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.white)
                    } trailingActions: { context in
                        SwipeAction("Delete") {
                            tasks.remove(at: index)
                        }
                        .foregroundColor(.white)
                        .background(.red)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity / 2)
            HStack {
                TextField("Add a task", text: $newTask)
                    .textFieldStyle(.plain)
                    .padding()
                    .tint(.black)
                Button(action: {
                    tasks.append(Task(name: newTask, completed: false))
                    newTask = ""
                }) {
                    Text("ADD").foregroundColor(.black)
                }
            }.padding(.horizontal, 25)
            VStack {
                Text("Consistency").font(.system(size: 20))
                ScrollView(.horizontal) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(40)), count: 7), spacing: 4) {
                        ForEach(0..<365) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(contributionColor(for: index))
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
    }

    private func contributionColor(for index: Int) -> Color {
        // Mock data - you can replace this with real contribution data
        let intensity = Double.random(in: 0...1)
        return Color.black.opacity(intensity)
    }
}

#Preview {
    ContentView()
}
