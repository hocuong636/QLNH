import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:quanlynhahang/constants/subscription_plans.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() => _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage> {
  FirebaseDatabase get _database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://quanlynhahang-d858b-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }
  
  DatabaseReference get _dbRef => _database.ref();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Quản Lý Gói Dịch Vụ',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quản lý các gói dịch vụ và giới hạn',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          // Hiển thị các gói dịch vụ
          ...SubscriptionPlan.allPlans.map((plan) {
            final limits = SubscriptionPlan.getLimits(plan);
            return _buildPlanCard(plan, limits);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String plan, Map<String, dynamic> limits) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPlanColor(plan).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    SubscriptionPlan.getDisplayName(plan),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getPlanColor(plan),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLimitRow('Số chi nhánh:', limits['maxBranches'] == -1 ? 'Không giới hạn' : '${limits['maxBranches']}'),
            const SizedBox(height: 8),
            _buildLimitRow('Số user:', limits['maxUsers'] == -1 ? 'Không giới hạn' : '${limits['maxUsers']}'),
            const SizedBox(height: 8),
            _buildLimitRow('Số đơn/ngày:', limits['maxOrdersPerDay'] == -1 ? 'Không giới hạn' : '${limits['maxOrdersPerDay']}'),
            const SizedBox(height: 12),
            const Text(
              'Tính năng:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (limits['features'] as List).map((feature) {
                return Chip(
                  label: Text(
                    feature == 'all' ? 'Tất cả tính năng' : feature,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade50,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Color _getPlanColor(String plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return Colors.grey;
      case SubscriptionPlan.basic:
        return Colors.blue;
      case SubscriptionPlan.pro:
        return Colors.purple;
      case SubscriptionPlan.enterprise:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

