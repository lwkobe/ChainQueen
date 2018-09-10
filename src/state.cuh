#pragma once

#include "state_base.h"

static constexpr int mpm_enalbe_apic = true;
static constexpr int mpm_enalbe_force = true;
static constexpr int particle_block_dim = 128;
static constexpr int grid_block_dim = 128;

template <int dim_>
struct TState : public TStateBase<dim_> {
  static constexpr int dim = dim_;
  using Base = TStateBase<dim>;

  using Base::num_particles;
  using Base::num_cells;
  using Base::V_p;
  using Base::m_p;
  using Base::E;
  using Base::nu;
  using Base::mu;
  using Base::lambda;
  using Base::dt;
  using Base::invD;
  using Base::dx;
  using Base::res;
  using Base::gravity;
  using Base::inv_dx;
  using Base::grid_storage;
  using Base::grad_grid_storage;
  using Base::x_storage;
  using Base::grad_x_storage;
  using Base::v_storage;
  using Base::grad_v_storage;
  using Base::F_storage;
  using Base::grad_F_storage;
  using Base::P_storage;
  using Base::grad_P_storage;
  using Base::C_storage;
  using Base::grad_C_storage;

  using VectorI = TVector<int, 3>;

  TState() {
    num_cells = res[0] * res[1] * res[2];
  }

  TC_FORCE_INLINE __host__ __device__ int grid_size() const {
    return num_cells;
  }

  TC_FORCE_INLINE __device__ int linearized_offset(int x, int y, int z) const {
    return res[2] * (res[1] * x + y) + z;
  }

  /*
  TC_FORCE_INLINE __device__ int linearized_offset(VectorI x) const {
    return res[2] * (res[1] * x[0] + x[1]) + x[2];
  }
  */

  TC_FORCE_INLINE __device__ real *grid_node(int offset) const {
    return grid_storage + (dim + 1) * offset;
  }

  TC_FORCE_INLINE __device__ real *grad_grid_node(int offset) const {
    return grad_grid_storage + (dim + 1) * offset;
  }

  TC_FORCE_INLINE __device__ real *grid_node(int x, int y, int z) const {
    return grid_node(linearized_offset(x, y, z));
  }

  TC_FORCE_INLINE __device__ real *grid_node(VectorI x) const {
    return grid_node(linearized_offset(x[0], x[1], x[2]));
  }

  TC_FORCE_INLINE __device__ real *grad_grid_node(int x, int y, int z) const {
    return grad_grid_node(linearized_offset(x, y, z));
  }

  TC_FORCE_INLINE __device__ real *grad_grid_node(VectorI x) const {
    return grad_grid_node(linearized_offset(x[0], x[1], x[2]));
  }

  template <int dim__ = dim_, typename _ = std::enable_if_t<dim_ == 3, void>>
  TC_FORCE_INLINE __device__ Matrix get_matrix(real *p, int part_id) const {
    return Matrix(
        p[part_id + 0 * num_particles], p[part_id + 1 * num_particles],
        p[part_id + 2 * num_particles], p[part_id + 3 * num_particles],
        p[part_id + 4 * num_particles], p[part_id + 5 * num_particles],
        p[part_id + 6 * num_particles], p[part_id + 7 * num_particles],
        p[part_id + 8 * num_particles]);
  }

  TC_FORCE_INLINE __device__ void set_matrix(real *p,
                                             int part_id,
                                             Matrix m) const {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        p[part_id + (i * 3 + j) * num_particles] = m[i][j];
      }
    }
  }

  TC_FORCE_INLINE __device__ Vector get_vector(real *p, int part_id) {
    return Vector(p[part_id], p[part_id + num_particles],
                  p[part_id + num_particles * 2]);
  }

  TC_FORCE_INLINE __device__ void set_vector(real *p, int part_id, Vector v) {
    for (int i = 0; i < dim; i++) {
      p[part_id + num_particles * i] = v[i];
    }
  }

  TC_FORCE_INLINE __device__ Vector get_grid_velocity(VectorI i) {
    auto g = grid_node(i);
    return Vector(g);
  }

  TC_FORCE_INLINE __device__ Vector get_grad_grid_velocity(VectorI i) {
    auto g = grad_grid_node(i);
    return Vector(g);
  }

  TC_FORCE_INLINE __device__ void set_grid_velocity(VectorI i, Vector v) {
    auto g = grid_node(i);
    for (int d = 0; d < dim; d++) {
      g[d] = v[d];
    }
  }

  TC_FORCE_INLINE __device__ void set_grad_grid_velocity(int i,
                                                         int j,
                                                         int k,
                                                         Vector v) {
    auto g = grad_grid_node(i, j, k);
    for (int d = 0; d < dim; d++) {
      g[d] = v[d];
    }
  }

  TC_FORCE_INLINE __device__ real get_grid_mass(VectorI i) {
    auto g = grid_node(i);
    return g[dim];
  }

#define TC_MPM_VECTOR(x)                                                \
  TC_FORCE_INLINE __device__ Vector get_##x(int part_id) {              \
    return get_vector(x##_storage, part_id);                            \
  }                                                                     \
  TC_FORCE_INLINE __device__ void set_##x(int part_id, Vector x) {      \
    return set_vector(x##_storage, part_id, x);                         \
  }                                                                     \
  TC_FORCE_INLINE __device__ Vector get_grad_##x(int part_id) {         \
    return get_vector(grad_##x##_storage, part_id);                     \
  }                                                                     \
  TC_FORCE_INLINE __device__ void set_grad_##x(int part_id, Vector x) { \
    return set_vector(grad_##x##_storage, part_id, x);                  \
  }

  TC_MPM_VECTOR(x);
  TC_MPM_VECTOR(v);

#define TC_MPM_MATRIX(F)                                                \
  TC_FORCE_INLINE __device__ Matrix get_##F(int part_id) {              \
    return get_matrix(F##_storage, part_id);                            \
  }                                                                     \
  TC_FORCE_INLINE __device__ void set_##F(int part_id, Matrix m) {      \
    return set_matrix(F##_storage, part_id, m);                         \
  }                                                                     \
  TC_FORCE_INLINE __device__ Matrix get_grad_##F(int part_id) {         \
    return get_matrix(grad_##F##_storage, part_id);                     \
  }                                                                     \
  TC_FORCE_INLINE __device__ void set_grad_##F(int part_id, Matrix m) { \
    return set_matrix(grad_##F##_storage, part_id, m);                  \
  }

  TC_MPM_MATRIX(F);
  TC_MPM_MATRIX(P);
  TC_MPM_MATRIX(C);

  TState(int res[dim],
         int num_particles,
         real dx,
         real dt,
         real gravity[dim],
         real *x_storage,
         real *v_storage,
         real *F_storage,
         real *C_storage,
         real *P_storage,
         real *grid_storage)
      : Base() {
    this->num_cells = 1;
    for (int i = 0; i < dim; i++) {
      this->res[i] = res[i];
      this->num_cells *= res[i];
      this->gravity[i] = gravity[i];
    }
    this->num_particles = num_particles;
    this->dx = dx;
    this->inv_dx = 1.0f / dx;
    this->dt = dt;
    this->invD = 4 * inv_dx * inv_dx;

    this->x_storage = x_storage;
    this->v_storage = v_storage;
    this->F_storage = F_storage;
    this->C_storage = C_storage;
    this->P_storage = P_storage;
    this->grid_storage = grid_storage;
  }

  TState(int res[dim],
         int num_particles,
         real dx,
         real dt,
         real gravity[dim],
         real *x_storage,
         real *v_storage,
         real *F_storage,
         real *C_storage,
         real *P_storage,
         real *grid_storage,
         real *grad_x_storage,
         real *grad_v_storage,
         real *grad_F_storage,
         real *grad_C_storage,
         real *grad_P_storage,
         real *grad_grid_storage)
      : TState(res,
               num_particles,
               dx,
               dt,
               gravity,
               x_storage,
               v_storage,
               F_storage,
               C_storage,
               P_storage,
               grid_storage) {
    this->grad_x_storage = grad_x_storage;
    this->grad_v_storage = grad_v_storage;
    this->grad_F_storage = grad_F_storage;
    this->grad_C_storage = grad_C_storage;
    this->grad_P_storage = grad_P_storage;
    this->grad_grid_storage = grad_grid_storage;
    // cudaMalloc(&this->grad_P_storage, sizeof(real) * dim * dim *
    // num_particles);
    // cudaMalloc(&this->grad_grid_storage, sizeof(real) * (dim + 1) * res[0] *
    // res[1] * res[2]);
  }

  TState(int res[dim], int num_particles, real dx, real dt, real gravity[dim])
      : TState(res,
               num_particles,
               dx,
               dt,
               gravity,
               NULL,
               NULL,
               NULL,
               NULL,
               NULL,
               NULL) {
    cudaMalloc(&x_storage, sizeof(real) * dim * num_particles);
    cudaMalloc(&v_storage, sizeof(real) * dim * num_particles);
    cudaMalloc(&F_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&C_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&P_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&grid_storage, sizeof(real) * (dim + 1) * num_cells);

    cudaMalloc(&grad_x_storage, sizeof(real) * dim * num_particles);
    cudaMalloc(&grad_v_storage, sizeof(real) * dim * num_particles);
    cudaMalloc(&grad_F_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&grad_C_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&grad_P_storage, sizeof(real) * dim * dim * num_particles);
    cudaMalloc(&grad_grid_storage, sizeof(real) * (dim + 1) * num_cells);

    std::vector<real> F_initial(num_particles * dim * dim, 0);
    for (int i = 0; i < num_particles; i++) {
      F_initial[i] = 1;
      F_initial[i + num_particles * 4] = 1;
      F_initial[i + num_particles * 8] = 1;
    }
    cudaMemcpy(F_storage, F_initial.data(), sizeof(Matrix) * num_particles,
               cudaMemcpyHostToDevice);
  }

  void clear_gradients() {
    cudaMemset(grad_v_storage, 0, sizeof(real) * dim * num_particles);
    cudaMemset(grad_x_storage, 0, sizeof(real) * dim * num_particles);
    cudaMemset(grad_F_storage, 0, sizeof(real) * dim * dim * num_particles);
    cudaMemset(grad_P_storage, 0, sizeof(real) * dim * dim * num_particles);
    cudaMemset(grad_C_storage, 0, sizeof(real) * dim * dim * num_particles);
    cudaMemset(grad_grid_storage, 0, num_cells * (dim + 1) * sizeof(real));
  }
};

constexpr int spline_size = 3;

using State = TState<3>;

template <int dim = 3, bool with_grad = false>
struct TransferCommon {
  TVector<int, 3> base_coord;
  Vector fx;
  real dx, inv_dx;
  using BSplineWeights = real[dim][spline_size];
  BSplineWeights weights[1 + (int)with_grad];

  TC_FORCE_INLINE __device__ TransferCommon(const State &state, Vector x) {
    dx = state.dx;
    inv_dx = state.inv_dx;
    for (int i = 0; i < dim; i++) {
      base_coord[i] = int(x[i] * inv_dx - 0.5);
      real f = (real)base_coord[i] - x[i] * inv_dx;
      static_assert(std::is_same<std::decay_t<decltype(fx[i])>, real>::value,
                    "");
      fx[i] = f;
    }

    // B-Spline weights
    for (int i = 0; i < dim; ++i) {
      weights[0][i][0] = 0.5f * sqr(1.5f + fx[i]);
      weights[0][i][1] = 0.75f - sqr(fx[i] + 1);
      weights[0][i][2] = 0.5f * sqr(fx[i] + 0.5f);
      //       printf("%f\n", weights[0][i][0] + weights[0][i][1] +
      //       weights[0][i][2]);
    }

    if (with_grad) {
      // N(x_i - x_p)
      // TODO: test
      for (int i = 0; i < dim; ++i) {
        weights[1][i][0] = -inv_dx * (1.5f + fx[i]);
        weights[1][i][1] = inv_dx * (2 * fx[i] + 2);
        weights[1][i][2] = -inv_dx * (fx[i] + 0.5f);
        // printf("%f\n", weights[1][i][0] + weights[1][i][1] +
        // weights[1][i][2]);
      }
    }
  }

  TC_FORCE_INLINE __device__ real w(int i, int j, int k) {
    return weights[0][0][i] * weights[0][1][j] * weights[0][2][k];
  }

  TC_FORCE_INLINE __device__ real w(int i) {
    return weights[0][0][i / 9] * weights[0][1][i / 3 % 3] *
           weights[0][2][i % 3];
  }

  template <bool _with_grad = with_grad>
  TC_FORCE_INLINE __device__ std::enable_if_t<_with_grad, Vector> dw(int i) {
    int j = i / 3 % 3, k = i % 3;
    i = i / 9;
    return Vector(weights[1][0][i] * weights[0][1][j] * weights[0][2][k],
                  weights[0][0][i] * weights[1][1][j] * weights[0][2][k],
                  weights[0][0][i] * weights[0][1][j] * weights[1][2][k]);
  }

  TC_FORCE_INLINE __device__ Vector dpos(int i, int j, int k) {
    return dx * (fx + Vector(i, j, k));
  }

  TC_FORCE_INLINE __device__ Vector dpos(int i) {
    return dx * (fx + Vector(i / 9, i / 3 % 3, i % 3));
  }
};

template <int dim>
__device__ constexpr int kernel_volume();

template <>
__device__ constexpr int kernel_volume<2>() {
  return 9;
}

template <>
__device__ constexpr int kernel_volume<3>() {
  return 27;
}

template <int dim>
__device__ TC_FORCE_INLINE TVector<int, dim> offset_from_scalar(int i);

template <>
__device__ TC_FORCE_INLINE TVector<int, 3> offset_from_scalar<3>(int i) {
  return TVector<int, 3>(i / 9, i / 3 % 3, i % 3);
};
