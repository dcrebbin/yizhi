//
//  ContentView.swift
//  yizhi
//
//  Created by Devon Crebbin on 17/12/2024.
//

import SwiftUI

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

    var body: some View {
        VStack(alignment: .center) {
            Text("一只 yīzhí").font(.system(size: 30))
            ScrollView {
                Text("今天 / today").font(.system(size: 20))
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    HStack {
                        Text(task.name)
                        Spacer()
                        //checkbox
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
                }
            }.frame(maxWidth: .infinity, maxHeight: 200)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
    }
}

#Preview {
    ContentView()
}
